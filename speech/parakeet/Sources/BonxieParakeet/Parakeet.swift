// Speech to text, by Parakeet TDT 0.6b v3 on Core ML (FluidAudio), for
// whoever has 16 kHz mono samples. Batch only: it makes text, with where
// each word ends, of the audio it is given, and the caller (see
// Speech.Windows) gives it a growing window to make a stream of it.
//
// Calls wait (the first loads, or downloads, the models; the rest run
// them), so the caller must not be the main thread. They may be called from
// any thread, but the model runs one at a time.

import Dispatch
import FluidAudio
import Foundation

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
    _ = why.withCString { strlcpy(message, $0, Int(room)) }
}

private func reason(_ error: Error) -> String {
    (error as? Failure)?.why ?? error.localizedDescription
}

private let lock = NSLock()
private var loaded: AsrManager?
private var preparing: Task<AsrManager, Error>?

// The model wants at least a second of sound.
private let rate = 16_000

private func place(_ directory: UnsafePointer<CChar>) -> URL {
    URL(fileURLWithPath: String(cString: directory), isDirectory: true)
}

// The models in directory, loaded and warmed, once: whoever asks while it
// is under way waits for the same one. Core ML compiles the models for the
// Neural Engine on the first load (the system keeps the result, for a
// while), and some of it only on the first prediction, so a second of
// silence is run here, for the first real call not to wait for it.
private func prepare(_ there: URL) -> Task<AsrManager, Error> {
    lock.withLock {
        if let task = preparing { return task }
        let task = Task.detached { () async throws -> AsrManager in
            do {
                guard AsrModels.modelsExist(at: there, version: .v3) else {
                    throw Failure(why: "The Parakeet model is not downloaded")
                }
                let models = try await AsrModels.load(from: there, version: .v3)
                let manager = AsrManager(config: .default)
                try await manager.loadModels(models)
                var state = try TdtDecoderState(decoderLayers: await manager.decoderLayerCount)
                _ = try? await manager.transcribe(
                    [Float](repeating: 0, count: rate), decoderState: &state)
                try Task.checkCancellation()
                lock.withLock {
                    loaded = manager
                    preparing = nil
                }
                return manager
            } catch {
                lock.withLock { preparing = nil }
                throw error
            }
        }
        preparing = task
        return task
    }
}

// 1 if the models are in directory (all of them).
@_cdecl("pk_present")
public func pk_present(_ directory: UnsafePointer<CChar>) -> Int32 {
    AsrModels.modelsExist(at: place(directory), version: .v3) ? 1 : 0
}

// 1 if the models are loaded; 0 if not, and message says why. They are
// those in directory (see pk_fetch_begin to put them there).
@_cdecl("pk_load")
public func pk_load(
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

// Begin to load and warm the models in the background, without waiting
// (for the start of the program: the system may have let go of what it
// compiled, and this is better than the first transcription finding out).
// Nothing happens if they are not downloaded, or are ready or on the way.
@_cdecl("pk_preload")
public func pk_preload(_ directory: UnsafePointer<CChar>) {
    let there = place(directory)
    guard lock.withLock({ loaded == nil }),
        AsrModels.modelsExist(at: there, version: .v3)
    else { return }
    _ = prepare(there)
}

// ---------------------------------------------------------------------
// Fetching the models, in the background, one fetch at a time: begin it,
// then poll its state (0 nothing, 1 running, 2 done, 3 failed), how much
// has come (0...1), and why it failed.

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

// The size, in bytes, of the files that a fetch brings: those of the
// models' folders, as the repository lists them. 0 if it cannot be listed.
private func remoteSize() async -> Int64 {
    struct Entry: Decodable {
        let type: String
        let size: Int64?
    }
    var total: Int64 = 0
    for name in ModelNames.ASR.requiredModelsV3().sorted() {
        let address = "https://huggingface.co/api/models/\(Repo.parakeetV3.remotePath)"
            + "/tree/main/\(name)?recursive=true"
        guard let url = URL(string: address),
            let (data, _) = try? await ModelHub.fetchWithAuth(from: url),
            let entries = try? JSONDecoder().decode([Entry].self, from: data)
        else { return 0 }
        total += entries.filter { $0.type == "file" }.reduce(0) { $0 + ($1.size ?? 0) }
    }
    return total
}

// 1 if it began; 0 if one is running already.
@_cdecl("pk_fetch_begin")
public func pk_fetch_begin(_ directory: UnsafePointer<CChar>) -> Int32 {
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
            // How many bytes there will be, for the caller to say; 0 if it
            // cannot be found out (the fetch goes on without).
            let total = await remoteSize()
            fetching.lock.withLock { fetching.total = total }
            // AsrModels.download makes one load (download, then compile) of
            // each model in turn, and its fraction restarts and stalls at
            // a half for every one. ModelHub.download is the same fetch, by
            // the byte, once; a repo's download is the first half of its
            // fraction (the other is compiling, which is done below).
            try await ModelHub.download(
                .parakeetV3, to: there.deletingLastPathComponent(),
                variant: ParakeetEncoderPrecision.int8.rawValue
            ) { progress in
                fetching.lock.withLock {
                    fetching.fraction = max(fetching.fraction, min(1, progress.fractionCompleted * 2))
                }
            }
            // This is a no-op once the models and vocabulary are there; it
            // is here for the vocabulary, should the above not have it.
            try await AsrModels.download(to: there, version: .v3)
            try Task.checkCancellation()
            // Then the compiling, which has no fraction: the caller says
            // it is preparing. The fetch is done when the first
            // transcription would not wait.
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

@_cdecl("pk_fetch_state")
public func pk_fetch_state() -> Int32 {
    fetching.lock.withLock { fetching.state }
}

@_cdecl("pk_fetch_fraction")
public func pk_fetch_fraction() -> Float {
    fetching.lock.withLock { Float(min(1, max(0, fetching.fraction))) }
}

// 1 while the fetch has it all and is compiling it (no fraction), else 0.
@_cdecl("pk_fetch_preparing")
public func pk_fetch_preparing() -> Int32 {
    fetching.lock.withLock { fetching.preparing ? 1 : 0 }
}

// The bytes the fetch comes to in all (0 until they are known, or if they
// cannot be).
@_cdecl("pk_fetch_total")
public func pk_fetch_total() -> Int64 {
    fetching.lock.withLock { fetching.total }
}

@_cdecl("pk_fetch_message")
public func pk_fetch_message(_ message: UnsafeMutablePointer<CChar>, _ room: Int32) {
    say(fetching.lock.withLock { fetching.why }, message, room)
}

// Forget how the last fetch ended (not while one is running).
@_cdecl("pk_fetch_reset")
public func pk_fetch_reset() {
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
@_cdecl("pk_fetch_cancel")
public func pk_fetch_cancel() {
    fetching.lock.withLock { fetching.task }?.cancel()
}

// Forget the models.
@_cdecl("pk_unload")
public func pk_unload() {
    lock.withLock {
        preparing?.cancel()
        preparing = nil
        loaded = nil
    }
}

// Make tokens of count samples: 1 if it is done (maybe with no tokens); 0
// if not, and message says why. Of the tokens (as many as tokenRoom, and
// whose text fits in textRoom bytes: no token is cut), tokenCount are
// given: their text, one after the other, in text (textLength bytes); the
// byte, from 1, that each ends at in textEnds; and where each starts and
// ends, in samples from the start of the audio, in starts and ends. The
// text is as the model has it: a token that begins a word begins with the
// SentencePiece space (U+2581), or a space; what is made of that is for
// the caller (see Speech.Words).
@_cdecl("pk_transcribe")
public func pk_transcribe(
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
    guard let manager = found else {
        say("The speech model is not loaded", message, messageRoom)
        return 0
    }
    var audio = Array(UnsafeBufferPointer(start: samples, count: Int(count)))
    if audio.count < rate {
        audio += [Float](repeating: 0, count: rate - audio.count)
    }
    let heard = audio
    let outcome = finish { () async throws -> [TokenTiming] in
        var state = try TdtDecoderState(decoderLayers: await manager.decoderLayerCount)
        let result = try await manager.transcribe(heard, decoderState: &state)
        return result.tokenTimings ?? []
    }
    switch outcome {
    case .failure(let error):
        say(reason(error), message, messageRoom)
        return 0
    case .success(let timings):
        var bytes = 0
        var given: Int32 = 0
        for timing in timings {
            let piece = Array(timing.token.utf8)
            if given >= tokenRoom || bytes + piece.count > Int(textRoom) { break }
            for (index, byte) in piece.enumerated() {
                text[bytes + index] = CChar(bitPattern: byte)
            }
            bytes += piece.count
            textEnds[Int(given)] = Int32(bytes)
            starts[Int(given)] = Int32(min(Double(count), max(0, timing.startTime * Double(rate))))
            ends[Int(given)] = Int32(min(Double(count), max(0, timing.endTime * Double(rate))))
            given += 1
        }
        textLength.pointee = Int32(bytes)
        tokenCount.pointee = given
        return 1
    }
}
