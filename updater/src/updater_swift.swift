// What Ada cannot do for the updater alone: Ed25519 and SHA-256, by CryptoKit, behind a C interface.

import CryptoKit
import Foundation

// 1 if the signature (base64) is Ed25519's of the message by the public key (base64, 32 bytes), else 0.
@_cdecl("upd_verify_ed25519")
public func upd_verify_ed25519(
    _ key: UnsafePointer<CChar>, _ message: UnsafePointer<UInt8>?, _ length: Int, _ signature: UnsafePointer<CChar>
) -> Int32 {
    let text = String(cString: signature).trimmingCharacters(in: .whitespacesAndNewlines)
    guard let raw = Data(base64Encoded: String(cString: key)),
        let publicKey = try? Curve25519.Signing.PublicKey(rawRepresentation: raw),
        let proof = Data(base64Encoded: text)
    else { return 0 }
    let bytes = message.map { Data(bytes: $0, count: length) } ?? Data()
    return publicKey.isValidSignature(proof, for: bytes) ? 1 : 0
}

// The SHA-256 of a file as 64 lowercase hex digits and a NUL, into hex (65 bytes); 1 if it was read, else 0.
@_cdecl("upd_sha256_file")
public func upd_sha256_file(_ path: UnsafePointer<CChar>, _ hex: UnsafeMutablePointer<CChar>) -> Int32 {
    guard let handle = FileHandle(forReadingAtPath: String(cString: path)) else { return 0 }
    defer { try? handle.close() }
    var hasher = SHA256()
    do {
        // (At the end of the file the read gives nothing, or no data.)
        while let chunk = try handle.read(upToCount: 1 << 20), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
    } catch {
        return 0
    }
    let digits = Array("0123456789abcdef".utf8)
    var at = 0
    for byte in hasher.finalize() {
        hex[at] = CChar(digits[Int(byte >> 4)])
        hex[at + 1] = CChar(digits[Int(byte & 15)])
        at += 2
    }
    hex[at] = 0
    return 1
}
