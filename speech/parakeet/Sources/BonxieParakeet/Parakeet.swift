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

// The model wants at least a second of sound.
private let rate = 16_000

private func place(_ directory: UnsafePointer<CChar>) -> URL {
    URL(fileURLWithPath: String(cString: directory), isDirectory: true)
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
    lock.lock()
    let already = loaded != nil
    lock.unlock()
    if already { return 1 }
    let there = place(directory)
    let outcome = finish { () async throws -> AsrManager in
        guard AsrModels.modelsExist(at: there, version: .v3) else {
            throw Failure(why: "The Parakeet model is not downloaded")
        }
        let models = try await AsrModels.load(from: there, version: .v3)
        let manager = AsrManager(config: .default)
        try await manager.loadModels(models)
        return manager
    }
    switch outcome {
    case .failure(let error):
        say(reason(error), message, room)
        return 0
    case .success(let manager):
        lock.lock()
        loaded = manager
        lock.unlock()
        return 1
    }
}

// ---------------------------------------------------------------------
// Fetching the models, in the background, one fetch at a time: begin it,
// then poll its state (0 nothing, 1 running, 2 done, 3 failed), how much
// has come (0...1), and why it failed.

private final class Fetching: @unchecked Sendable {
    let lock = NSLock()
    var state: Int32 = 0
    var fraction = 0.0
    var why = ""
    var task: Task<Void, Never>?
}

private let fetching = Fetching()

// 1 if it began; 0 if one is running already.
@_cdecl("pk_fetch_begin")
public func pk_fetch_begin(_ directory: UnsafePointer<CChar>) -> Int32 {
    let there = place(directory)
    fetching.lock.lock()
    defer { fetching.lock.unlock() }
    if fetching.state == 1 { return 0 }
    fetching.state = 1
    fetching.fraction = 0
    fetching.why = ""
    fetching.task = Task.detached {
        do {
            // AsrModels.download makes one load (download, then compile) of
            // each model in turn, and its fraction restarts and stalls at
            // a half for every one. ModelHub.download is the same fetch, by
            // the byte, once; a repo's download is the first half of its
            // fraction (the other is compiling, which is not done here).
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
            fetching.lock.withLock {
                fetching.fraction = 1
                fetching.state = 2
            }
        } catch {
            fetching.lock.withLock {
                fetching.why = Task.isCancelled ? "Cancelled" : reason(error)
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
            fetching.why = ""
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
    lock.lock()
    loaded = nil
    lock.unlock()
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
