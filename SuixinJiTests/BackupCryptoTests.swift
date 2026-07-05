import XCTest
import SwiftData
@testable import SuixinJi

/// Encrypted backup (evolution · 数据加密). AES-GCM + PBKDF2 round-trip and failure modes.
final class BackupCryptoTests: XCTestCase {

    private let plaintext = Data("随心记备份内容 · diary payload 🌿".utf8)

    func testRoundTrip() throws {
        let enc = try BackupCrypto.encrypt(plaintext, password: "correct horse")
        XCTAssertNotEqual(enc, plaintext)                 // actually encrypted
        XCTAssertTrue(BackupCrypto.isEncrypted(enc))       // carries the magic header
        let dec = try BackupCrypto.decrypt(enc, password: "correct horse")
        XCTAssertEqual(dec, plaintext)
    }

    func testWrongPasswordFails() throws {
        let enc = try BackupCrypto.encrypt(plaintext, password: "right")
        XCTAssertThrowsError(try BackupCrypto.decrypt(enc, password: "wrong")) { err in
            XCTAssertEqual(err as? BackupCrypto.CryptoError, .wrongPassword)
        }
    }

    func testTamperedCiphertextFails() throws {
        var enc = try BackupCrypto.encrypt(plaintext, password: "pw")
        enc[enc.count - 1] ^= 0xFF                          // flip the last byte (in the GCM tag)
        XCTAssertThrowsError(try BackupCrypto.decrypt(enc, password: "pw")) { err in
            XCTAssertEqual(err as? BackupCrypto.CryptoError, .wrongPassword)
        }
    }

    func testIsEncryptedDetection() throws {
        let enc = try BackupCrypto.encrypt(plaintext, password: "pw")
        XCTAssertTrue(BackupCrypto.isEncrypted(enc))
        XCTAssertFalse(BackupCrypto.isEncrypted(Data("{\"version\":1}".utf8))) // plain JSON
        XCTAssertFalse(BackupCrypto.isEncrypted(Data()))
    }

    func testGarbageFailsBadFormat() {
        XCTAssertThrowsError(try BackupCrypto.decrypt(Data([1, 2, 3]), password: "pw")) { err in
            XCTAssertEqual(err as? BackupCrypto.CryptoError, .badFormat)
        }
    }

    func testDifferentPasswordsProduceDifferentCiphertext() throws {
        let a = try BackupCrypto.encrypt(plaintext, password: "a")
        let b = try BackupCrypto.encrypt(plaintext, password: "b")
        XCTAssertNotEqual(a, b) // different keys + random salt/nonce
    }

    // MARK: End-to-end via BackupService

    func testEncryptedBackupServiceRoundTrip() throws {
        let container = try ModelContainer(for: DiaryEntry.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let srcCtx = ModelContext(container)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("enc-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let store = FileStoreImpl(root: root)

        let e = DiaryEntry(text: "加密往返", mood: "😊")
        srcCtx.insert(e); try srcCtx.save()

        let raw = try BackupService.exportData(from: [e], fileStore: store)
        let encrypted = try BackupCrypto.encrypt(raw, password: "s3cret")

        let dstCtx = ModelContext(try ModelContainer(
            for: DiaryEntry.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
        // Wrong password → rejected.
        XCTAssertThrowsError(try BackupService.importData(encrypted, into: dstCtx, fileStore: store, password: "nope"))
        // No password on an encrypted blob → rejected.
        XCTAssertThrowsError(try BackupService.importData(encrypted, into: dstCtx, fileStore: store))
        // Correct password → restored.
        let r = try BackupService.importData(encrypted, into: dstCtx, fileStore: store, password: "s3cret")
        XCTAssertEqual(r.imported, 1)
        XCTAssertEqual(try dstCtx.fetch(FetchDescriptor<DiaryEntry>()).first?.text, "加密往返")
    }
}
