import XCTest
import SwiftData
import UIKit
@testable import SuixinJi

/// Full backup export → import round-trip (evolution). Uses in-memory SwiftData
/// and temp FileStores so entries AND media are verified end to end.
@MainActor
final class BackupServiceTests: XCTestCase {

    private func makeContext() throws -> ModelContext {
        let c = try ModelContainer(for: DiaryEntry.self,
                                   configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        return ModelContext(c)
    }

    private func makeStore() -> (FileStoreImpl, URL) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("bak-\(UUID().uuidString)")
        return (FileStoreImpl(root: root), root)
    }

    private func image() -> UIImage {
        let f = UIGraphicsImageRendererFormat.default(); f.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: 40, height: 40), format: f).image { c in
            UIColor.orange.setFill(); c.fill(CGRect(x: 0, y: 0, width: 40, height: 40))
        }
    }

    private func tempAudio() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("rec-\(UUID().uuidString).m4a")
        try Data([0xAA, 0xBB, 0xCC]).write(to: url)
        return url
    }

    func testExportImportRoundTripRestoresEntriesAndMedia() throws {
        // Source: two entries, one with a photo + audio.
        let srcCtx = try makeContext()
        let (srcStore, srcRoot) = makeStore(); defer { try? FileManager.default.removeItem(at: srcRoot) }

        let imgName = try srcStore.saveImage(image())
        let audioName = try srcStore.adoptAudio(tempURL: tempAudio())
        let e1 = DiaryEntry(text: "有图有音", mood: "😊", tags: ["旅行"],
                            imageFileNames: [imgName], audioFileName: audioName, audioDuration: 7)
        let e2 = DiaryEntry(text: "纯文字")
        srcCtx.insert(e1); srcCtx.insert(e2)
        try srcCtx.save()

        let data = try BackupService.exportData(from: [e1, e2], fileStore: srcStore)

        // Destination: a fresh, empty store + context.
        let dstCtx = try makeContext()
        let (dstStore, dstRoot) = makeStore(); defer { try? FileManager.default.removeItem(at: dstRoot) }

        let result = try BackupService.importData(data, into: dstCtx, fileStore: dstStore)
        XCTAssertEqual(result.imported, 2)
        XCTAssertEqual(result.skipped, 0)

        let restored = try dstCtx.fetch(FetchDescriptor<DiaryEntry>())
        XCTAssertEqual(restored.count, 2)
        let withMedia = try XCTUnwrap(restored.first { $0.text == "有图有音" })
        XCTAssertEqual(withMedia.mood, "😊")
        XCTAssertEqual(withMedia.tags, ["旅行"])
        XCTAssertEqual(withMedia.imageFileNames, [imgName])
        XCTAssertEqual(withMedia.audioFileName, audioName)
        // Media bytes actually restored to the destination sandbox.
        XCTAssertNotNil(dstStore.loadImage(imgName))
        XCTAssertEqual(try Data(contentsOf: dstStore.audioURL(audioName)), Data([0xAA, 0xBB, 0xCC]))
    }

    func testImportIsIdempotentMergeByID() throws {
        let srcCtx = try makeContext()
        let (store, root) = makeStore(); defer { try? FileManager.default.removeItem(at: root) }
        let e = DiaryEntry(text: "只此一篇")
        srcCtx.insert(e); try srcCtx.save()
        let data = try BackupService.exportData(from: [e], fileStore: store)

        let dstCtx = try makeContext()
        let first = try BackupService.importData(data, into: dstCtx, fileStore: store)
        XCTAssertEqual(first.imported, 1)
        // Re-importing the same backup skips the already-present id.
        let second = try BackupService.importData(data, into: dstCtx, fileStore: store)
        XCTAssertEqual(second.imported, 0)
        XCTAssertEqual(second.skipped, 1)
        XCTAssertEqual(try dstCtx.fetch(FetchDescriptor<DiaryEntry>()).count, 1)
    }

    func testBackupPreservesIdsAndVersion() throws {
        let (store, root) = makeStore(); defer { try? FileManager.default.removeItem(at: root) }
        let e = DiaryEntry(text: "x")
        let backup = BackupService.makeBackup(from: [e], fileStore: store, now: Date())
        XCTAssertEqual(backup.version, 1)
        XCTAssertEqual(backup.entries.first?.id, e.id)
    }

    func testImportRejectsGarbage() throws {
        let dstCtx = try makeContext()
        let (store, root) = makeStore(); defer { try? FileManager.default.removeItem(at: root) }
        XCTAssertThrowsError(
            try BackupService.importData(Data("not a backup".utf8), into: dstCtx, fileStore: store)
        )
    }
}
