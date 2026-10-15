// Local language models on MLX, by mlx-swift-lm, for whoever has the folder
// of a model's files (a Hugging Face snapshot). Only models converted for
// MLX run: mx_check says whether one will, and mx_generate runs a prompt
// through one.
//
// This is a thin binding: what is asked, how it is tasked and what is made
// of the reply are the caller's (see MLX.Jobs). mx_generate waits, for
// the model to load (once: it is kept until mx_unload or another is asked
// for) and for the reply, so the caller must not be the main thread. Calls
// may be made from any thread; the model runs one at a time.

import Dispatch
import Foundation
import MLXLLM
import MLXLMCommon
import Tokenizers

private struct Failure: Error {
    let why: String
}

private final class Outcome<T>: @unchecked Sendable {
    var result: Result<T, Error>?
}

// Run async work to its end, while the caller waits.
private func finish<T: Sendable>(_ work: @escaping @Sendable () async throws -> T)
    -> Result<T, Error>
{
    let done = DispatchSemaphore(value: 0)
    let outcome = Outcome<T>()
    Task.detached {
        do {
            outcome.result = .success(try await work())
        } catch {
            outcome.result = .failure(error)
        }
        done.signal()
    }
    done.wait()
    return outcome.result!
}

private func say(_ why: String, _ message: UnsafeMutablePointer<CChar>, _ room: Int32) {
    guard room > 0 else { return }
    _ = why.withCString { strlcpy(message, $0, Int(room)) }
}

private func reason(_ error: Error) -> String {
    (error as? Failure)?.why ?? error.localizedDescription
}

// MARK: - Tokenizer (swift-transformers, as mlx-swift-lm's)

private struct TokenizerBridge: MLXLMCommon.Tokenizer {
    let upstream: any Tokenizers.Tokenizer

    func encode(text: String, addSpecialTokens: Bool) -> [Int] {
        upstream.encode(text: text, addSpecialTokens: addSpecialTokens)
    }

    func decode(tokenIds: [Int], skipSpecialTokens: Bool) -> String {
        upstream.decode(tokens: tokenIds, skipSpecialTokens: skipSpecialTokens)
    }

    func convertTokenToId(_ token: String) -> Int? { upstream.convertTokenToId(token) }
    func convertIdToToken(_ id: Int) -> String? { upstream.convertIdToToken(id) }

    var bosToken: String? { upstream.bosToken }
    var eosToken: String? { upstream.eosToken }
    var unknownToken: String? { upstream.unknownToken }

    func applyChatTemplate(
        messages: [[String: any Sendable]],
        tools: [[String: any Sendable]]?,
        additionalContext: [String: any Sendable]?
    ) throws -> [Int] {
        do {
            return try upstream.applyChatTemplate(
                messages: messages, tools: tools, additionalContext: additionalContext)
        } catch Tokenizers.TokenizerError.missingChatTemplate {
            throw MLXLMCommon.TokenizerError.missingChatTemplate
        }
    }
}

private struct LocalTokenizers: MLXLMCommon.TokenizerLoader {
    func load(from directory: URL) async throws -> any MLXLMCommon.Tokenizer {
        TokenizerBridge(upstream: try await AutoTokenizer.from(modelFolder: directory))
    }
}

// MARK: - Is it an MLX model

private func place(_ directory: UnsafePointer<CChar>) -> URL {
    URL(fileURLWithPath: String(cString: directory), isDirectory: true)
}

// The "format" in a safetensors file's header ("mlx" for a model converted
// for MLX, "pt" for one that is not), nil if it says none.
private func format(of file: URL) throws -> String? {
    let handle = try FileHandle(forReadingFrom: file)
    defer { try? handle.close() }
    guard let head = try handle.read(upToCount: 8), head.count == 8 else {
        throw Failure(why: "\(file.lastPathComponent) is not a safetensors file")
    }
    let size = head.withUnsafeBytes { $0.loadUnaligned(as: UInt64.self) }.littleEndian
    guard size > 0, size < 100_000_000, let json = try handle.read(upToCount: Int(size)),
        let table = try JSONSerialization.jsonObject(with: json) as? [String: Any]
    else {
        throw Failure(why: "\(file.lastPathComponent) has no readable header")
    }
    return (table["__metadata__"] as? [String: Any])?["format"] as? String
}

// Why the model in directory will not run, nil if it will.
private func problem(with directory: URL) async -> String? {
    let files = FileManager.default
    guard files.fileExists(atPath: directory.path) else {
        return "The model's folder is not there"
    }
    let names = (try? files.contentsOfDirectory(atPath: directory.path)) ?? []
    let weights = names.filter { $0.hasSuffix(".safetensors") }.sorted()
    guard let first = weights.first else {
        return "Not an MLX model: it has no safetensors files"
    }
    guard let data = try? Data(contentsOf: directory.appendingPathComponent("config.json")),
        let config = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else {
        return "Not an MLX model: it has no config.json"
    }
    do {
        switch try format(of: directory.appendingPathComponent(first)) {
        case "mlx": break
        case .some(let other):
            return "Not an MLX model: its weights are in the \"\(other)\" format"
        case .none:
            // Some conversions leave the format out; they are quantized.
            if config["quantization"] == nil {
                return "Not an MLX model: its weights are not marked as MLX"
            }
        }
    } catch {
        return reason(error)
    }
    guard let type = config["model_type"] as? String else {
        return "The model's config.json has no model_type"
    }
    if !(await LLMTypeRegistry.shared.contains(type)) {
        return "The model type \"\(type)\" is not supported"
    }
    return nil
}

// 1 if the model in directory is an MLX model that can run here; 0 if not,
// and message says why.
@_cdecl("mx_check")
public func mx_check(
    _ directory: UnsafePointer<CChar>, _ message: UnsafeMutablePointer<CChar>, _ room: Int32
) -> Int32 {
    message[0] = 0
    let there = place(directory)
    switch finish({ await problem(with: there) }) {
    case .success(let why?):
        say(why, message, room)
        return 0
    default:
        return 1
    }
}

// MARK: - Generation

// The model in memory: the one last asked for, kept for the next.
private actor Engine {
    private var path: String?
    private var container: ModelContainer?

    func model(at directory: URL) async throws -> ModelContainer {
        if let container, path == directory.path { return container }
        container = nil  // let go of one before loading another
        path = nil
        if let why = await problem(with: directory) { throw Failure(why: why) }
        let loaded = try await loadModelContainer(from: directory, using: LocalTokenizers())
        container = loaded
        path = directory.path
        return loaded
    }

    func unload() {
        container = nil
        path = nil
    }

    var isLoaded: Bool { container != nil }
}

private let engine = Engine()

private let lock = NSLock()
private var running: [Int64: Task<String, Error>] = [:]  // by the caller's job number

private func string(_ pointer: UnsafePointer<CChar>?) -> String? {
    guard let pointer else { return nil }
    let text = String(cString: pointer)
    return text.isEmpty ? nil : text
}

// Ask the model in directory, with the system prompt (none if NULL or
// empty) and the prompt, and say what it replies, as it said it (a model
// that thinks aloud says that too: <think>...</think>) in text.
//
// What is tuned is left to the model's own where it is negative: the
// sampling temperature, top_p (0...1), top_k (0 turns it off), min_p,
// repetition_penalty and its context, the most tokens to make, and seed (to
// make the same reply again). thinking is 0 to ask a model that can think
// not to, 1 to ask it to, and otherwise it is left to the model.
//
// job is the caller's own number for this call, for mx_cancel. 1 if the
// model replied; 0 if it could not, and message says why; 2 if the call
// was cancelled.
@_cdecl("mx_generate")
public func mx_generate(
    _ directory: UnsafePointer<CChar>,
    _ system: UnsafePointer<CChar>?,
    _ prompt: UnsafePointer<CChar>,
    _ maxTokens: Int32,
    _ temperature: Float,
    _ topP: Float,
    _ topK: Int32,
    _ minP: Float,
    _ repetitionPenalty: Float,
    _ repetitionContext: Int32,
    _ seed: Int64,
    _ thinking: Int32,
    _ job: Int64,
    _ text: UnsafeMutablePointer<CChar>, _ textRoom: Int32,
    _ message: UnsafeMutablePointer<CChar>, _ messageRoom: Int32
) -> Int32 {
    text[0] = 0
    message[0] = 0
    let there = place(directory)
    let instructions = string(system)
    let asked = String(cString: prompt)

    var tuning = GenerateParameters()
    if maxTokens >= 0 { tuning.maxTokens = Int(maxTokens) }
    if temperature >= 0 { tuning.temperature = temperature }
    if topP >= 0 { tuning.topP = topP }
    if topK >= 0 { tuning.topK = Int(topK) }
    if minP >= 0 { tuning.minP = minP }
    if repetitionPenalty >= 0 { tuning.repetitionPenalty = repetitionPenalty }
    if repetitionContext >= 0 { tuning.repetitionContextSize = Int(repetitionContext) }
    if seed >= 0 { tuning.seed = UInt64(seed) }
    let context: [String: any Sendable]? =
        thinking < 0 ? nil : ["enable_thinking": thinking == 1]
    let chosen = tuning

    let done = DispatchSemaphore(value: 0)
    let outcome = Outcome<String>()
    let work = Task.detached { () async throws -> String in
        let container = try await engine.model(at: there)
        try Task.checkCancellation()
        let session = ChatSession(
            container, instructions: instructions, generateParameters: chosen,
            additionalContext: context)
        let said = try await session.respond(to: asked)
        try Task.checkCancellation()
        return said
    }
    lock.withLock { running[job] = work }
    Task.detached {
        outcome.result = await work.result
        done.signal()
    }
    done.wait()
    lock.withLock { _ = running.removeValue(forKey: job) }

    switch outcome.result! {
    case .success(let said):
        say(said, text, textRoom)
        return 1
    case .failure(let error):
        if error is CancellationError || Task.isCancelled { return 2 }
        say(reason(error), message, messageRoom)
        return 0
    }
}

// Stop the call that has this job number, if it is running: it returns 2.
@_cdecl("mx_cancel")
public func mx_cancel(_ job: Int64) {
    lock.withLock { running[job]?.cancel() }
}

// Stop every call that is running (for when the program is ending).
@_cdecl("mx_cancel_all")
public func mx_cancel_all() {
    lock.withLock { for (_, work) in running { work.cancel() } }
}

// Let go of the model in memory, if there is one.
@_cdecl("mx_unload")
public func mx_unload() {
    _ = finish { await engine.unload() }
}

// 1 if a model is in memory.
@_cdecl("mx_loaded")
public func mx_loaded() -> Int32 {
    switch finish({ await engine.isLoaded }) {
    case .success(true): return 1
    default: return 0
    }
}
