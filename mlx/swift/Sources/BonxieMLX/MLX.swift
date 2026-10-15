// Local language models on MLX, by mlx-swift-lm, for whoever has the folder
// of a model's files (a Hugging Face snapshot). Only models converted for
// MLX run: mx_check says whether one will, and mx_test_begin runs a prompt
// through one, in the background, for the caller to poll.
//
// None of the calls wait for long: mx_check reads two small files, and the
// test runs on its own thread. They may be called from any thread.

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

// MARK: - The test

private let prompt = "This is a test, reply, in a single sentence, if it works"

private let lock = NSLock()
private var state: Int32 = 0  // 0 idle, 1 running, 2 done, 3 failed
private var text = ""  // the reply, or why it failed
private var running: Task<Void, Never>?
private var generation = 0  // which test is the current one

// Take out any thinking a model does aloud, which is not the reply.
private func reply(from raw: String) -> String {
    var shown = raw
    while let open = shown.range(of: "<think>") {
        if let close = shown.range(of: "</think>", range: open.upperBound..<shown.endIndex) {
            shown.removeSubrange(open.lowerBound..<close.upperBound)
        } else {
            shown.removeSubrange(open.lowerBound..<shown.endIndex)
        }
    }
    if let close = shown.range(of: "</think>") {
        shown.removeSubrange(shown.startIndex..<close.upperBound)
    }
    shown = shown.trimmingCharacters(in: .whitespacesAndNewlines)
    return shown.isEmpty ? raw.trimmingCharacters(in: .whitespacesAndNewlines) : shown
}

private func conclude(_ new: Int32, _ words: String, of job: Int) {
    lock.withLock {
        if state == 1 && generation == job {
            state = new
            text = words
        }
    }
}

// Begin to run the test prompt through the model in directory, in the
// background. 1 if it began, 0 if a test is running already.
@_cdecl("mx_test_begin")
public func mx_test_begin(_ directory: UnsafePointer<CChar>) -> Int32 {
    let there = place(directory)
    return lock.withLock {
        if state == 1 { return 0 }
        state = 1
        text = ""
        generation += 1
        let job = generation
        running = Task.detached {
            do {
                if let why = await problem(with: there) { throw Failure(why: why) }
                let container = try await loadModelContainer(
                    from: there, using: LocalTokenizers())
                let session = ChatSession(
                    container, generateParameters: GenerateParameters(maxTokens: 512))
                let said = try await session.respond(to: prompt)
                conclude(2, reply(from: said), of: job)
            } catch {
                conclude(3, reason(error), of: job)
            }
        }
        return 1
    }
}

// 0 if no test was begun (or it was forgotten), 1 running, 2 done, 3 failed.
@_cdecl("mx_test_state")
public func mx_test_state() -> Int32 {
    lock.withLock { state }
}

// The reply, once the test is done, or why it failed.
@_cdecl("mx_test_text")
public func mx_test_text(_ into: UnsafeMutablePointer<CChar>, _ room: Int32) {
    into[0] = 0
    say(lock.withLock { text }, into, room)
}

// Forget how the last test ended (and let go of a running one).
@_cdecl("mx_test_reset")
public func mx_test_reset() {
    lock.withLock {
        running?.cancel()
        running = nil
        generation += 1
        state = 0
        text = ""
    }
}
