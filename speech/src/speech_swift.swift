// Speech to text, by SpeechAnalyzer (macOS 26): the microphone is listened
// to, on-device, and what is said comes back as text. SpeechAnalyzer has
// no Objective-C or C interface, so this is Swift, with a C one on top
// (sp_begin, sp_end) for Ada.
//
// A session is one listening, told apart by number. Both calls wait (for
// leave to use the microphone, for the language's model to be installed
// the first time, for the speech to be finished), so the caller must not
// be the main thread. They may be called from any thread, and from
// several at once, for different sessions.

import AVFoundation
import Dispatch
import Foundation
import Speech

private struct Failure: Error {
    let why: String
}

private final class Listening: @unchecked Sendable {
    let engine = AVAudioEngine()
    var analyzer: SpeechAnalyzer?
    var feed: AsyncStream<AnalyzerInput>.Continuation?
    var collected: Task<String, Error>?
    // How loud it is now, 0...1, falling away between sounds: written by
    // the audio thread, read by sp_level (a stale value does no harm).
    var level: Float = 0
    // What has been said so far: the results that are final, and the
    // latest that is not (which the next result replaces). Written by
    // the collecting task, read by sp_peek.
    let heard = NSLock()
    var finals = ""
    var provisional = ""
}

private let lock = NSLock()
private var sessions: [Int32: Listening] = [:]

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

private func start(_ session: Listening) async throws {
    guard await AVAudioApplication.requestRecordPermission() else {
        throw Failure(why: "Microphone use was not allowed")
    }
    guard let locale = await SpeechTranscriber.supportedLocale(equivalentTo: Locale.current)
    else {
        throw Failure(why: "Speech is not supported in this language")
    }
    // The progressive preset reports volatile results as soon as they are
    // guessed (.fastResults), not at a pause.
    let transcriber = SpeechTranscriber(locale: locale, preset: .progressiveTranscription)
    if let request = try await AssetInventory.assetInstallationRequest(
        supporting: [transcriber])
    {
        try await request.downloadAndInstall()
    }
    guard let format = await SpeechAnalyzer.bestAvailableAudioFormat(
        compatibleWith: [transcriber])
    else {
        throw Failure(why: "No audio format for speech")
    }
    let analyzer = SpeechAnalyzer(
        modules: [transcriber], options: .init(priority: .userInitiated, modelRetention: .lingering))
    session.analyzer = analyzer
    // Load the model now, so that the first words do not wait for it.
    try await analyzer.prepareToAnalyze(in: format)
    let input = session.engine.inputNode
    let heard = input.outputFormat(forBus: 0)
    guard heard.sampleRate > 0, let converter = AVAudioConverter(from: heard, to: format)
    else {
        throw Failure(why: "No microphone")
    }
    let (stream, feed) = AsyncStream.makeStream(of: AnalyzerInput.self)
    session.feed = feed
    input.installTap(onBus: 0, bufferSize: 1024, format: heard) { buffer, _ in
        let room = AVAudioFrameCount(
            Double(buffer.frameLength) * format.sampleRate / heard.sampleRate) + 1024
        guard let made = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: room) else {
            return
        }
        var given = false
        var problem: NSError?
        converter.convert(to: made, error: &problem) { _, status in
            if given {
                status.pointee = .noDataNow
                return nil
            }
            given = true
            status.pointee = .haveData
            return buffer
        }
        if let samples = buffer.floatChannelData?[0], buffer.frameLength > 0 {
            var sum: Float = 0
            for index in 0..<Int(buffer.frameLength) { sum += samples[index] * samples[index] }
            let loud = min(1, (sum / Float(buffer.frameLength)).squareRoot() * 12)
            session.level = max(loud, session.level * 0.7)
        }
        if problem == nil && made.frameLength > 0 {
            feed.yield(AnalyzerInput(buffer: made))
        }
    }
    session.collected = Task(priority: .userInitiated) {
        for try await result in transcriber.results {
            let said = String(result.text.characters)
            session.heard.withLock {
                if result.isFinal {
                    session.finals += said + " "
                    session.provisional = ""
                } else {
                    session.provisional = said
                }
            }
        }
        return session.heard.withLock { session.finals }
    }
    try await analyzer.start(inputSequence: stream)
    session.engine.prepare()
    try session.engine.start()
}

private func stop(_ session: Listening) {
    session.engine.stop()
    session.engine.inputNode.removeTap(onBus: 0)
    session.feed?.finish()
}

// 1 if it is listening; 0 if not, and message says why.
@_cdecl("sp_begin")
public func sp_begin(_ number: Int32, _ message: UnsafeMutablePointer<CChar>, _ room: Int32)
    -> Int32
{
    message[0] = 0
    let session = Listening()
    lock.lock()
    let taken = sessions[number] != nil
    if !taken { sessions[number] = session }
    lock.unlock()
    if taken {
        say("Already listening", message, room)
        return 0
    }
    let outcome = finish { try await start(session) }
    if case .failure(let error) = outcome {
        stop(session)
        session.collected?.cancel()
        lock.lock()
        sessions[number] = nil
        lock.unlock()
        say(reason(error), message, room)
        return 0
    }
    return 1
}

// How loud the microphone is, of an open session, from 0 to 1.
@_cdecl("sp_level")
public func sp_level(_ number: Int32) -> Float {
    lock.lock()
    let found = sessions[number]
    lock.unlock()
    return found?.level ?? 0
}

// Copy words into text, as many as fit, not cutting a UTF-8 character.
private func copy(
    _ words: String, _ text: UnsafeMutablePointer<CChar>, _ room: Int32,
    _ length: UnsafeMutablePointer<Int32>, _ truncated: UnsafeMutablePointer<Int32>
) {
    var bytes = Array(words.utf8)
    if bytes.count > Int(room) {
        bytes = Array(bytes[0..<Int(room)])
        // Not in the middle of a UTF-8 character.
        while let last = bytes.last, last & 0xC0 == 0x80 { bytes.removeLast() }
        if let last = bytes.last, last & 0x80 != 0 { bytes.removeLast() }
        truncated.pointee = 1
    }
    for (index, byte) in bytes.enumerated() { text[index] = CChar(bitPattern: byte) }
    length.pointee = Int32(bytes.count)
}

// What has been said so far in an open session, final or not yet: 1 if
// the session is open (maybe with nothing said), else 0.
@_cdecl("sp_peek")
public func sp_peek(
    _ number: Int32, _ text: UnsafeMutablePointer<CChar>, _ textRoom: Int32,
    _ length: UnsafeMutablePointer<Int32>, _ truncated: UnsafeMutablePointer<Int32>
) -> Int32 {
    length.pointee = 0
    truncated.pointee = 0
    lock.lock()
    let found = sessions[number]
    lock.unlock()
    guard let session = found else { return 0 }
    let words = session.heard.withLock { session.finals + session.provisional }
        .trimmingCharacters(in: .whitespacesAndNewlines)
    copy(words, text, textRoom, length, truncated)
    return 1
}

// 1 if it finished (maybe with nothing said); 0 if not, and message says why.
@_cdecl("sp_end")
public func sp_end(
    _ number: Int32, _ text: UnsafeMutablePointer<CChar>, _ textRoom: Int32,
    _ length: UnsafeMutablePointer<Int32>, _ truncated: UnsafeMutablePointer<Int32>,
    _ message: UnsafeMutablePointer<CChar>, _ messageRoom: Int32
) -> Int32 {
    message[0] = 0
    length.pointee = 0
    truncated.pointee = 0
    lock.lock()
    let found = sessions.removeValue(forKey: number)
    lock.unlock()
    guard let session = found else {
        say("Not listening", message, messageRoom)
        return 0
    }
    stop(session)
    let outcome = finish {
        try await session.analyzer?.finalizeAndFinishThroughEndOfInput()
        return try await session.collected?.value ?? ""
    }
    switch outcome {
    case .failure(let error):
        session.collected?.cancel()
        say(reason(error), message, messageRoom)
        return 0
    case .success(let said):
        let words = said.trimmingCharacters(in: .whitespacesAndNewlines)
        copy(words, text, textRoom, length, truncated)
        return 1
    }
}

// ---------------------------------------------------------------------
// Capture: the microphone, as 16 kHz mono samples, for a model that wants
// them (and does not take 44.1 kHz stereo). The converting is done here,
// in the audio tap, as the sound arrives; the samples are given to Ada
// (sp_ring_push, which keeps them in a ring for Speech.Capture.Read to take,
// and the loudness with them). The tap does no more than that: it takes no
// lock, and, once begun, makes nothing (it converts into one buffer that it
// keeps), so that nothing a reader does can hold it up.

private let capRate: Double = 16_000
private let capFrames: AVAudioFrameCount = 16_384

private final class Capture: @unchecked Sendable {
    let engine = AVAudioEngine()
}

private let capLock = NSLock()
private var captures: [Int32: Capture] = [:]

private func startCapture(_ capture: Capture, _ number: Int32) async throws {
    guard await AVAudioApplication.requestRecordPermission() else {
        throw Failure(why: "Microphone use was not allowed")
    }
    guard let format = AVAudioFormat(
        commonFormat: .pcmFormatFloat32, sampleRate: capRate, channels: 1, interleaved: false),
        let made = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capFrames)
    else {
        throw Failure(why: "No audio format for speech")
    }
    let input = capture.engine.inputNode
    let heard = input.outputFormat(forBus: 0)
    guard heard.sampleRate > 0, let converter = AVAudioConverter(from: heard, to: format)
    else {
        throw Failure(why: "No microphone")
    }
    // How loud it is, falling away between sounds: only the tap's.
    var smoothed: Float = 0
    input.installTap(onBus: 0, bufferSize: 1024, format: heard) { buffer, _ in
        let room = AVAudioFrameCount(Double(buffer.frameLength) * capRate / heard.sampleRate) + 1024
        guard room <= capFrames else {
            return
        }
        var given = false
        var problem: NSError?
        converter.convert(to: made, error: &problem) { _, status in
            if given {
                status.pointee = .noDataNow
                return nil
            }
            given = true
            status.pointee = .haveData
            return buffer
        }
        guard problem == nil, made.frameLength > 0, let data = made.floatChannelData?[0]
        else {
            return
        }
        let count = Int(made.frameLength)
        var sum: Float = 0
        for index in 0..<count { sum += data[index] * data[index] }
        let loud = min(1, (sum / Float(count)).squareRoot() * 12)
        smoothed = max(loud, smoothed * 0.7)
        sp_ring_push(number, data, Int32(count), smoothed.bitPattern)
    }
    capture.engine.prepare()
    try capture.engine.start()
}

// 1 if the microphone is being heard; 0 if not, and message says why. Waits
// for leave to use the microphone: not for the main thread.
@_cdecl("sp_cap_begin")
public func sp_cap_begin(_ number: Int32, _ message: UnsafeMutablePointer<CChar>, _ room: Int32)
    -> Int32
{
    message[0] = 0
    let capture = Capture()
    capLock.lock()
    let taken = captures[number] != nil
    if !taken { captures[number] = capture }
    capLock.unlock()
    if taken {
        say("Already listening", message, room)
        return 0
    }
    let outcome = finish { try await startCapture(capture, number) }
    if case .failure(let error) = outcome {
        capture.engine.stop()
        capture.engine.inputNode.removeTap(onBus: 0)
        capLock.lock()
        captures[number] = nil
        capLock.unlock()
        say(reason(error), message, room)
        return 0
    }
    return 1
}

// Stop hearing; what has been heard stays to be read.
@_cdecl("sp_cap_stop")
public func sp_cap_stop(_ number: Int32) {
    capLock.lock()
    let found = captures[number]
    capLock.unlock()
    guard let capture = found else { return }
    capture.engine.stop()
    capture.engine.inputNode.removeTap(onBus: 0)
}

// Stop, and forget the session.
@_cdecl("sp_cap_close")
public func sp_cap_close(_ number: Int32) {
    sp_cap_stop(number)
    capLock.lock()
    captures[number] = nil
    capLock.unlock()
}
