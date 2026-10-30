// Speech to text, by Granite Speech 5.0 2B (4-bit) on MLX (mlx-audio-swift),
// for whoever has 16 kHz mono samples. The same shape as BonxieParakeet (it
// takes the audio it is given and makes words of it, with where each ends),
// so Speech.Windows can make a stream of it the same way.
//
// The model does not say when a word was spoken: the words are spread over
// the part of the audio that is not silence, each by its length. They are in
// order and inside the audio, which is what the caller needs, and the
// caller's settling (the last words stay tentative until there is sound
// after them) stands on that.
//
// Calls wait (the first loads the model; the rest run it), so the caller
// must not be the main thread. They may be called from any thread, but the
// model runs one at a time.

import Dispatch
import Foundation
import MLX
import MLXAudioSTT

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

private let rate = 16_000

private func place(_ directory: UnsafePointer<CChar>) -> URL {
    URL(fileURLWithPath: String(cString: directory), isDirectory: true)
}

// The repository the model comes from, and the files of it that are used
// (the others, out_llm.safetensors for speculative decoding and the
// readme, are not).
private let repository = "fncsftya/granite-speech-5.0-2b-mlx-4bit"
private let wanted = [
    "added_tokens.json", "chat_template.jinja", "config.json", "generation_config.json", "merges.txt",
    "model.safetensors", "model.safetensors.index.json", "preprocessor_config.json",
    "processor_config.json", "special_tokens_map.json", "tokenizer.json", "tokenizer_config.json",
    "vocab.json",
]

private func isThere(_ directory: URL) -> Bool {
    let files = FileManager.default
    return wanted.allSatisfy { name in
        let size = (try? files.attributesOfItem(atPath: directory.appendingPathComponent(name).path))?[.size]
        return ((size as? NSNumber)?.int64Value ?? 0) > 0
    }
}

private let lock = NSLock()
private var loaded: GraniteSpeechModel?
private var preparing: Task<GraniteSpeechModel, Error>?

// The model in directory, loaded and warmed, once: whoever asks while it is
// under way waits for the same one. A second of silence is run, for the
// first real call not to wait for the GPU's kernels.
private func prepare(_ there: URL) -> Task<GraniteSpeechModel, Error> {
    lock.withLock {
        if let task = preparing { return task }
        let task = Task.detached { () async throws -> GraniteSpeechModel in
            do {
                guard isThere(there) else {
                    throw Failure(why: "The Granite model is not downloaded")
                }
                let model = try await GraniteSpeechModel.fromModelDirectory(there)
                _ = model.generate(audio: MLXArray([Float](repeating: 0, count: rate)), maxTokens: 1)
                try Task.checkCancellation()
                lock.withLock {
                    loaded = model
                    preparing = nil
                }
                return model
            } catch {
                lock.withLock { preparing = nil }
                throw error
            }
        }
        preparing = task
        return task
    }
}

// 1 if the model is in directory (all of it).
@_cdecl("gr_present")
public func gr_present(_ directory: UnsafePointer<CChar>) -> Int32 {
    isThere(place(directory)) ? 1 : 0
}

// 1 if the model is loaded; 0 if not, and message says why.
@_cdecl("gr_load")
public func gr_load(
    _ directory: UnsafePointer<CChar>, _ message: UnsafeMutablePointer<CChar>, _ room: Int32
) -> Int32 {
    message[0] = 0
    if lock.withLock({ loaded != nil }) { return 1 }
    let task = prepare(place(directory))
    switch finish({ try await task.value }) {
    case .failure(let error):
        say(reason(error), message, room)
        return 0
    case .success:
        return 1
    }
}

// Begin to load and warm the model in the background, without waiting.
// Nothing happens if it is not downloaded, or is ready or on the way.
@_cdecl("gr_preload")
public func gr_preload(_ directory: UnsafePointer<CChar>) {
    let there = place(directory)
    guard lock.withLock({ loaded == nil }), isThere(there) else { return }
    _ = prepare(there)
}

// ---------------------------------------------------------------------
// Fetching the model, in the background, one fetch at a time: begin it,
// then poll its state (0 nothing, 1 running, 2 done, 3 failed), how much
// has come (0...1), and why it failed. Each file comes to a ".part" file
// that is renamed when it is whole, so what is named is whole.

private final class Fetching: @unchecked Sendable {
    let lock = NSLock()
    var state: Int32 = 0
    var fraction = 0.0
    var total: Int64 = 0
    var why = ""
    var preparing = false
    var task: Task<Void, Never>?
}

private let fetching = Fetching()

private struct Listing: Decodable {
    struct Entry: Decodable {
        let rfilename: String
        let size: Int64?
    }
    let siblings: [Entry]
}

// Counts the bytes of one file as they come.
private final class Piece: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    let onBytes: @Sendable (Int64) -> Void
    var finished: CheckedContinuation<URL, Error>?
    var moved: URL?
    var last: Int64 = 0

    init(onBytes: @escaping @Sendable (Int64) -> Void) { self.onBytes = onBytes }

    func urlSession(
        _ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData written: Int64,
        totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64
    ) {
        onBytes(totalBytesWritten - last)
        last = totalBytesWritten
    }

    func urlSession(
        _ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL
    ) {
        // The system removes the file when this returns: keep it.
        let kept = location.deletingLastPathComponent().appendingPathComponent(UUID().uuidString)
        do {
            if let http = downloadTask.response as? HTTPURLResponse, http.statusCode != 200 {
                throw Failure(why: "Hugging Face answered \(http.statusCode)")
            }
            try FileManager.default.moveItem(at: location, to: kept)
            moved = kept
        } catch {
            finished?.resume(throwing: error)
            finished = nil
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let continuation = finished else { return }
        finished = nil
        if let error = error {
            continuation.resume(throwing: error)
        } else if let kept = moved {
            continuation.resume(returning: kept)
        } else {
            continuation.resume(throwing: Failure(why: "A file did not come"))
        }
    }
}

private func download(_ name: String, to directory: URL, count: @escaping @Sendable (Int64) -> Void)
    async throws
{
    guard let url = URL(string: "https://huggingface.co/\(repository)/resolve/main/\(name)") else {
        throw Failure(why: "No address for \(name)")
    }
    let piece = Piece(onBytes: count)
    let session = URLSession(configuration: .default, delegate: piece, delegateQueue: nil)
    defer { session.finishTasksAndInvalidate() }
    let kept: URL = try await withTaskCancellationHandler {
        try await withCheckedThrowingContinuation { continuation in
            piece.finished = continuation
            session.downloadTask(with: url).resume()
        }
    } onCancel: {
        session.invalidateAndCancel()
    }
    try Task.checkCancellation()
    let target = directory.appendingPathComponent(name)
    let partial = directory.appendingPathComponent(name + ".part")
    try? FileManager.default.removeItem(at: partial)
    try FileManager.default.moveItem(at: kept, to: partial)
    try? FileManager.default.removeItem(at: target)
    try FileManager.default.moveItem(at: partial, to: target)
}

// The size, in bytes, of the files that a fetch brings, as the repository
// lists them (and the sizes by name). 0 if it cannot be listed.
private func remoteSizes() async -> [String: Int64] {
    guard let url = URL(string: "https://huggingface.co/api/models/\(repository)?blobs=true"),
        let (data, _) = try? await URLSession.shared.data(from: url),
        let listing = try? JSONDecoder().decode(Listing.self, from: data)
    else { return [:] }
    var sizes: [String: Int64] = [:]
    for entry in listing.siblings where wanted.contains(entry.rfilename) {
        sizes[entry.rfilename] = entry.size ?? 0
    }
    return sizes
}

// 1 if it began; 0 if one is running already.
@_cdecl("gr_fetch_begin")
public func gr_fetch_begin(_ directory: UnsafePointer<CChar>) -> Int32 {
    let there = place(directory)
    fetching.lock.lock()
    defer { fetching.lock.unlock() }
    if fetching.state == 1 { return 0 }
    fetching.state = 1
    fetching.fraction = 0
    fetching.total = 0
    fetching.why = ""
    fetching.preparing = false
    fetching.task = Task.detached {
        do {
            try FileManager.default.createDirectory(at: there, withIntermediateDirectories: true)
            let sizes = await remoteSizes()
            let total = sizes.values.reduce(0, +)
            fetching.lock.withLock { fetching.total = total }
            // A file already whole is not fetched again.
            var came: Int64 = 0
            var todo: [String] = []
            for name in wanted {
                let path = there.appendingPathComponent(name).path
                let size = ((try? FileManager.default.attributesOfItem(atPath: path))?[.size] as? NSNumber)?
                    .int64Value ?? 0
                if size > 0, size == (sizes[name] ?? size) {
                    came += size
                } else {
                    todo.append(name)
                }
            }
            let base = came
            let soFar = Counter(base)
            // The bytes that have come are the fraction; the loading, which
            // is done below, has none.
            let report: @Sendable (Int64) -> Void = { more in
                let now = soFar.add(more)
                fetching.lock.withLock {
                    if total > 0 {
                        fetching.fraction = max(fetching.fraction, min(1, Double(now) / Double(total)))
                    }
                }
            }
            for name in todo {
                try await download(name, to: there, count: report)
                try Task.checkCancellation()
            }
            guard isThere(there) else {
                throw Failure(why: "The Granite model did not come whole")
            }
            // Then the loading, which has no fraction: the caller says it is
            // preparing. The fetch is done when the first transcription
            // would not wait.
            fetching.lock.withLock {
                fetching.fraction = 1
                fetching.preparing = true
            }
            _ = try await prepare(there).value
            fetching.lock.withLock {
                fetching.preparing = false
                fetching.state = 2
            }
        } catch {
            fetching.lock.withLock {
                fetching.why = Task.isCancelled ? "Cancelled" : reason(error)
                fetching.preparing = false
                fetching.state = 3
            }
        }
    }
    return 1
}

private final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Int64
    init(_ start: Int64) { value = start }
    func add(_ more: Int64) -> Int64 { lock.withLock { value += more; return value } }
}

@_cdecl("gr_fetch_state")
public func gr_fetch_state() -> Int32 {
    fetching.lock.withLock { fetching.state }
}

@_cdecl("gr_fetch_fraction")
public func gr_fetch_fraction() -> Float {
    fetching.lock.withLock { Float(min(1, max(0, fetching.fraction))) }
}

// 1 while the fetch has it all and is loading it (no fraction), else 0.
@_cdecl("gr_fetch_preparing")
public func gr_fetch_preparing() -> Int32 {
    fetching.lock.withLock { fetching.preparing ? 1 : 0 }
}

// The bytes the fetch comes to in all (0 until they are known, or if they
// cannot be).
@_cdecl("gr_fetch_total")
public func gr_fetch_total() -> Int64 {
    fetching.lock.withLock { fetching.total }
}

@_cdecl("gr_fetch_message")
public func gr_fetch_message(_ message: UnsafeMutablePointer<CChar>, _ room: Int32) {
    say(fetching.lock.withLock { fetching.why }, message, room)
}

// Forget how the last fetch ended (not while one is running).
@_cdecl("gr_fetch_reset")
public func gr_fetch_reset() {
    fetching.lock.withLock {
        if fetching.state != 1 {
            fetching.state = 0
            fetching.fraction = 0
            fetching.total = 0
            fetching.why = ""
            fetching.preparing = false
        }
    }
}

// Stop a fetch that is running; it ends as failed.
@_cdecl("gr_fetch_cancel")
public func gr_fetch_cancel() {
    fetching.lock.withLock { fetching.task }?.cancel()
}

// Forget the model.
@_cdecl("gr_unload")
public func gr_unload() {
    lock.withLock {
        preparing?.cancel()
        preparing = nil
        loaded = nil
    }
    Memory.clearCache()
}

// Where the sound is, in samples: from the first frame of 20 ms that is
// louder than the quietest by a good deal to the end of the last. All of
// it if there is no telling.
private func voiced(_ audio: [Float]) -> (Int, Int) {
    let frame = rate / 50
    guard audio.count >= frame * 2 else { return (0, audio.count) }
    var levels: [Float] = []
    var start = 0
    while start + frame <= audio.count {
        var sum: Float = 0
        for index in start..<(start + frame) { sum += audio[index] * audio[index] }
        levels.append(sum / Float(frame))
        start += frame
    }
    let floor = levels.sorted()[levels.count / 10]
    let threshold = max(floor * 8, 1e-6)
    guard let first = levels.firstIndex(where: { $0 > threshold }),
        let last = levels.lastIndex(where: { $0 > threshold })
    else { return (0, audio.count) }
    return (first * frame, min(audio.count, (last + 1) * frame))
}

// Make words of count samples: 1 if it is done (maybe with no words); 0 if
// not, and message says why. The arguments and what is given are as
// pk_transcribe's: a "token" is a word, which begins with a space.
@_cdecl("gr_transcribe")
public func gr_transcribe(
    _ samples: UnsafePointer<Float>, _ count: Int32,
    _ text: UnsafeMutablePointer<CChar>, _ textRoom: Int32, _ textLength: UnsafeMutablePointer<Int32>,
    _ tokenRoom: Int32, _ tokenCount: UnsafeMutablePointer<Int32>,
    _ textEnds: UnsafeMutablePointer<Int32>, _ starts: UnsafeMutablePointer<Int32>,
    _ ends: UnsafeMutablePointer<Int32>,
    _ message: UnsafeMutablePointer<CChar>, _ messageRoom: Int32
) -> Int32 {
    message[0] = 0
    textLength.pointee = 0
    tokenCount.pointee = 0
    lock.lock()
    let found = loaded
    lock.unlock()
    guard let model = found else {
        say("The speech model is not loaded", message, messageRoom)
        return 0
    }
    var audio = Array(UnsafeBufferPointer(start: samples, count: Int(count)))
    if audio.count < rate {
        audio += [Float](repeating: 0, count: rate - audio.count)
    }
    let heard = audio
    let outcome = finish { () async throws -> String in
        model.generate(audio: MLXArray(heard), punctuate: true).text
    }
    switch outcome {
    case .failure(let error):
        say(reason(error), message, messageRoom)
        return 0
    case .success(let said):
        let words = said.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard !words.isEmpty else { return 1 }
        let (from, to) = voiced(Array(heard.prefix(Int(count))))
        let span = Double(max(0, to - from))
        let weights = words.map { Double($0.count + 1) }
        let weight = weights.reduce(0, +)
        var bytes = 0
        var given: Int32 = 0
        var at = Double(from)
        for (index, word) in words.enumerated() {
            let piece = Array((" " + word).utf8)
            if given >= tokenRoom || bytes + piece.count > Int(textRoom) { break }
            for (offset, byte) in piece.enumerated() {
                text[bytes + offset] = CChar(bitPattern: byte)
            }
            bytes += piece.count
            let length = span * weights[index] / weight
            let begin = Int32(min(Double(count), max(0, at)))
            at += length
            let finish = Int32(min(Double(count), max(Double(begin), at)))
            textEnds[Int(given)] = Int32(bytes)
            starts[Int(given)] = begin
            ends[Int(given)] = finish
            given += 1
        }
        textLength.pointee = Int32(bytes)
        tokenCount.pointee = given
        return 1
    }
}
