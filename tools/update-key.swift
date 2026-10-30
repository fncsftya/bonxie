// The author's side of updates, with CryptoKit (the same Ed25519 the program checks with).
//
//     swift tools/update-key.swift generate <private-key-file>     make a key pair; print the public key
//     swift tools/update-key.swift public   <private-key-file>     print the public key of a private key
//     swift tools/update-key.swift sign     <private-key-file> <file>     print the signature of the file (base64)
//     swift tools/update-key.swift verify   <public-key-base64> <file> <signature-file>   exit 0 if it holds
//
// The private key file holds the 32 bytes of the key's seed as base64; `generate` makes it readable by its owner
// alone and will not replace one that is there.

import CryptoKit
import Foundation

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

func privateKey(_ path: String) -> Curve25519.Signing.PrivateKey {
    guard let text = try? String(contentsOfFile: path, encoding: .utf8),
        let seed = Data(base64Encoded: text.trimmingCharacters(in: .whitespacesAndNewlines)),
        let key = try? Curve25519.Signing.PrivateKey(rawRepresentation: seed)
    else { fail("cannot read a private key from \(path)") }
    return key
}

let arguments = CommandLine.arguments
guard arguments.count >= 3 else { fail("usage: update-key.swift generate|public|sign|verify ...") }

switch arguments[1] {
case "generate":
    let path = arguments[2]
    if FileManager.default.fileExists(atPath: path) { fail("\(path) exists; it is not replaced") }
    let key = Curve25519.Signing.PrivateKey()
    let folder = (path as NSString).deletingLastPathComponent
    if !folder.isEmpty { try? FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true) }
    let made = FileManager.default.createFile(
        atPath: path, contents: Data((key.rawRepresentation.base64EncodedString() + "\n").utf8),
        attributes: [.posixPermissions: 0o600])
    if !made { fail("cannot write \(path)") }
    print(key.publicKey.rawRepresentation.base64EncodedString())
case "public":
    print(privateKey(arguments[2]).publicKey.rawRepresentation.base64EncodedString())
case "sign":
    guard arguments.count == 4, let data = FileManager.default.contents(atPath: arguments[3]) else {
        fail("sign <private-key-file> <file>")
    }
    guard let signature = try? privateKey(arguments[2]).signature(for: data) else { fail("cannot sign") }
    print(signature.base64EncodedString())
case "verify":
    guard arguments.count == 5, let key = Data(base64Encoded: arguments[2]),
        let publicKey = try? Curve25519.Signing.PublicKey(rawRepresentation: key),
        let data = FileManager.default.contents(atPath: arguments[3]),
        let text = try? String(contentsOfFile: arguments[4], encoding: .utf8),
        let signature = Data(base64Encoded: text.trimmingCharacters(in: .whitespacesAndNewlines))
    else { fail("verify <public-key-base64> <file> <signature-file>") }
    exit(publicKey.isValidSignature(signature, for: data) ? 0 : 1)
default:
    fail("unknown command \(arguments[1])")
}
