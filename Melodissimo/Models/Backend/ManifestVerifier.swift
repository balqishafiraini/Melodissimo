//
//  ManifestVerifier.swift
//  Melodissimo
//

import CryptoKit
import Foundation

/// Checks that a content release is the one we signed: an Ed25519 signature over the exact manifest bytes, and a
/// SHA-256 for every file (`BACKEND_PLAN.md` §4.3, §5.2). Any trusted key may have made the signature, so a key can
/// be rotated by shipping the new public key in the app first and signing with it later.
struct ManifestVerifier {

    /// Public keys (32 raw bytes, base64) whose signatures are accepted. `k1` is `~/.melodissimo/keys/k1/public.key`.
    static let trustedKeys: [String] = ["hevy2AlVbLD9oSzDtvvtrTC1DmAASzQUi5sE24uv2DI="]

    let keys: [Curve25519.Signing.PublicKey]

    init(trustedKeys: [String] = ManifestVerifier.trustedKeys) {
        keys = trustedKeys.compactMap { text in
            Data(base64Encoded: text.trimmingCharacters(in: .whitespacesAndNewlines))
                .flatMap { try? Curve25519.Signing.PublicKey(rawRepresentation: $0) }
        }
    }

    /// Whether `signature` (base64, 64 bytes) is a valid signature of `manifest` by any trusted key.
    func verifySignature(of manifest: Data, signature: String) -> Bool {
        guard let raw = Data(base64Encoded: signature.trimmingCharacters(in: .whitespacesAndNewlines)), raw.count == 64 else { return false }
        return keys.contains { $0.isValidSignature(raw, for: manifest) }
    }

    static func sha256Hex(of data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    /// The SHA-256 of a file, read in 1 MB chunks so a long audio file is never held in memory.
    static func sha256Hex(ofFileAt url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        var hasher = SHA256()
        while true {
            let chunk: Data?
            do { chunk = try handle.read(upToCount: 1 << 20) } catch { return nil }
            // `read` returns nil (or empty data) at the end of the file.
            guard let chunk, !chunk.isEmpty else { break }
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    static func fileMatches(_ url: URL, sha256: String) -> Bool {
        sha256Hex(ofFileAt: url) == sha256.lowercased()
    }
}
