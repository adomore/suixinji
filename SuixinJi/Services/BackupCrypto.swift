import Foundation
import CryptoKit
import CommonCrypto

/// Password-based encryption for the full backup file (evolution · 数据加密).
/// AES-256-GCM with a key derived from the password via PBKDF2-HMAC-SHA256.
/// Envelope: magic(8) ‖ salt(16) ‖ AES.GCM.combined(nonce ‖ ciphertext ‖ tag).
/// Pure & unit-testable.
enum BackupCrypto {
    enum CryptoError: Error, Equatable { case badFormat, wrongPassword }

    static let magic = Data("SXJENC1\n".utf8)   // 8 bytes, identifies an encrypted backup
    static let saltLength = 16
    private static let iterations: UInt32 = 120_000

    /// True if `data` looks like a SuixinJi encrypted backup (magic prefix).
    static func isEncrypted(_ data: Data) -> Bool {
        data.count >= magic.count && data.prefix(magic.count) == magic
    }

    static func encrypt(_ plaintext: Data, password: String) throws -> Data {
        let salt = randomBytes(saltLength)
        let key = deriveKey(password: password, salt: salt)
        let sealed = try AES.GCM.seal(plaintext, using: key)
        guard let combined = sealed.combined else { throw CryptoError.badFormat }
        var out = Data()
        out.append(magic)
        out.append(salt)
        out.append(combined)
        return out
    }

    static func decrypt(_ input: Data, password: String) throws -> Data {
        guard isEncrypted(input), input.count > magic.count + saltLength else { throw CryptoError.badFormat }
        // Normalize to a 0-based Data so the integer-offset slicing below is safe
        // even if a sliced Data (non-zero startIndex) is passed in.
        let data = Data(input)
        let salt = data.subdata(in: magic.count ..< magic.count + saltLength)
        let combined = data.subdata(in: (magic.count + saltLength) ..< data.count)
        let key = deriveKey(password: password, salt: salt)
        do {
            let box = try AES.GCM.SealedBox(combined: combined)
            return try AES.GCM.open(box, using: key)   // fails (throws) on wrong password or tamper
        } catch {
            throw CryptoError.wrongPassword
        }
    }

    // MARK: - Key derivation

    static func deriveKey(password: String, salt: Data) -> SymmetricKey {
        let pwd = Data(password.utf8)
        var derived = [UInt8](repeating: 0, count: 32)
        // Empty password: derive from an empty-but-valid buffer (UI enforces a min length).
        let pwdBytes = pwd.isEmpty ? Data([0]) : pwd
        _ = pwdBytes.withUnsafeBytes { pwPtr in
            salt.withUnsafeBytes { saltPtr in
                CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2),
                    pwPtr.baseAddress!.assumingMemoryBound(to: CChar.self), pwd.count,
                    saltPtr.baseAddress!.assumingMemoryBound(to: UInt8.self), salt.count,
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256), iterations,
                    &derived, derived.count
                )
            }
        }
        return SymmetricKey(data: Data(derived))
    }

    private static func randomBytes(_ count: Int) -> Data {
        var data = Data(count: count)
        _ = data.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, count, $0.baseAddress!) }
        return data
    }
}
