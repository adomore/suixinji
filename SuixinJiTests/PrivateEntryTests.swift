import XCTest
import SwiftData
@testable import SuixinJi

/// 私密日记 (evolution). The persistence, backup round-trip, Spotlight exclusion,
/// and redaction gate for entries marked `isPrivate`.
final class PrivateEntryTests: XCTestCase {

    // MARK: Spotlight exclusion (pure)

    func testSpotlightExcludesPrivateEntries() {
        let pub = DiaryEntry(text: "公开", isPrivate: false)
        let priv = DiaryEntry(text: "秘密", isPrivate: true)
        let indexable = SpotlightIndexer.indexable([pub, priv])
        XCTAssertEqual(indexable.map(\.id), [pub.id])           // only the public one
        XCTAssertFalse(indexable.contains { $0.isPrivate })
    }

    // MARK: Backup round-trip

    func testBackupRoundTripPreservesPrivateFlag() throws {
        let container = try ModelContainer(for: DiaryEntry.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let src = ModelContext(container)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("priv-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let store = FileStoreImpl(root: root)

        let secret = DiaryEntry(text: "私密内容", isPrivate: true)
        let open = DiaryEntry(text: "公开内容", isPrivate: false)
        src.insert(secret); src.insert(open); try src.save()

        let data = try BackupService.exportData(from: [secret, open], fileStore: store)
        let dst = ModelContext(try ModelContainer(for: DiaryEntry.self,
                                                  configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
        let r = try BackupService.importData(data, into: dst, fileStore: store)
        XCTAssertEqual(r.imported, 2)

        let restored = try dst.fetch(FetchDescriptor<DiaryEntry>())
        XCTAssertEqual(restored.first { $0.text == "私密内容" }?.isPrivate, true)
        XCTAssertEqual(restored.first { $0.text == "公开内容" }?.isPrivate, false)
    }

    /// An older backup produced before this feature has no `isPrivate` key; it must
    /// still decode, defaulting to false rather than throwing.
    func testDecodingBackupWithoutPrivateKeyDefaultsFalse() throws {
        let json = """
        {
          "version": 1,
          "exportedAt": "2026-01-01T00:00:00Z",
          "entries": [{
            "id": "\(UUID().uuidString)",
            "createdAt": "2026-01-01T00:00:00Z",
            "diaryDate": "2026-01-01T00:00:00Z",
            "updatedAt": "2026-01-01T00:00:00Z",
            "text": "老备份",
            "tags": [],
            "imageFileNames": []
          }],
          "media": []
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(DiaryBackup.self, from: Data(json.utf8))
        XCTAssertNil(backup.entries.first?.isPrivate)
        XCTAssertEqual(backup.entries.first?.makeEntry().isPrivate, false)
    }

    // MARK: Persistence via DiaryService

    func testDiaryServiceSavesPrivateFlag() throws {
        let container = try ModelContainer(for: DiaryEntry.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let ctx = ModelContext(container)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("svc-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let store = FileStoreImpl(root: root)

        var draft = DiaryDraft(text: "标记为私密")
        draft.isPrivate = true
        let entry = try DiaryService.save(draft, existing: nil, into: ctx, fileStore: store)
        XCTAssertTrue(entry.isPrivate)
    }

    // MARK: Redaction gate

    @MainActor
    func testPrivacyManagerRedactsPrivateUntilRevealed() {
        let privacy = PrivacyManager()
        let secret = DiaryEntry(text: "秘密", isPrivate: true)
        let open = DiaryEntry(text: "公开", isPrivate: false)
        XCTAssertFalse(privacy.isRevealed)
        XCTAssertTrue(privacy.isHidden(secret))    // private + not revealed → hidden
        XCTAssertFalse(privacy.isHidden(open))     // public → never hidden
        privacy.conceal()
        XCTAssertFalse(privacy.isRevealed)         // conceal is idempotent
        XCTAssertTrue(privacy.isHidden(secret))
    }
}
