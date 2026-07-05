import XCTest
import SwiftData
import UIKit
@testable import SuixinJi

/// Media-file iCloud sync (F11 media step). Verifies `MediaBlob` ⇄ `FileStore`
/// reconciliation — upload (via one-time migration), download, orphan cleanup,
/// deletion, and crucially that a deleted blob is **not resurrected**. In-memory
/// SwiftData + temp FileStores (the CloudKit transport itself is device-verified).
@MainActor
final class MediaSyncServiceTests: XCTestCase {

    private func makeContext() throws -> ModelContext {
        let c = try ModelContainer(for: Schema([DiaryEntry.self, MediaBlob.self]),
                                   configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        return ModelContext(c)
    }

    private func makeStore() -> (FileStoreImpl, URL) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("sync-\(UUID().uuidString)")
        return (FileStoreImpl(root: root), root)
    }

    /// A pristine, per-test defaults so the one-time migration always fires here.
    private func freshDefaults() -> UserDefaults {
        let suite = "media-test-\(UUID().uuidString)"
        let d = UserDefaults(suiteName: suite)!
        addTeardownBlock { d.removePersistentDomain(forName: suite) }
        return d
    }

    private func image() -> UIImage {
        let f = UIGraphicsImageRendererFormat.default(); f.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: 30, height: 30), format: f).image { c in
            UIColor.systemTeal.setFill(); c.fill(CGRect(x: 0, y: 0, width: 30, height: 30))
        }
    }

    private func tempAudio() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("rec-\(UUID().uuidString).m4a")
        try Data([0x01, 0x02, 0x03]).write(to: url)
        return url
    }

    private func blobs(_ ctx: ModelContext) throws -> [MediaBlob] {
        try ctx.fetch(FetchDescriptor<MediaBlob>())
    }

    // MARK: Upload (local file → synced blob, via one-time migration)

    func testReconcileUploadsReferencedLocalMedia() throws {
        let ctx = try makeContext()
        let (store, root) = makeStore(); defer { try? FileManager.default.removeItem(at: root) }

        let imgName = try store.saveImage(image())
        let audioName = try store.adoptAudio(tempURL: tempAudio())
        let e = DiaryEntry(text: "有图有音", imageFileNames: [imgName], audioFileName: audioName, audioDuration: 3)
        ctx.insert(e); try ctx.save()

        MediaSyncService.reconcile(context: ctx, fileStore: store, defaults: freshDefaults())

        let all = try blobs(ctx)
        XCTAssertEqual(Set(all.map(\.name)), [imgName, audioName])
        let audioBlob = try XCTUnwrap(all.first { $0.name == audioName })
        XCTAssertEqual(audioBlob.kind, "audio")
        XCTAssertEqual(audioBlob.data, Data([0x01, 0x02, 0x03]))
        XCTAssertEqual(all.first { $0.name == imgName }?.kind, "image")
    }

    func testReconcileIsIdempotent() throws {
        let ctx = try makeContext()
        let (store, root) = makeStore(); defer { try? FileManager.default.removeItem(at: root) }
        let imgName = try store.saveImage(image())
        ctx.insert(DiaryEntry(text: "x", imageFileNames: [imgName])); try ctx.save()

        let d = freshDefaults()
        MediaSyncService.reconcile(context: ctx, fileStore: store, defaults: d)
        MediaSyncService.reconcile(context: ctx, fileStore: store, defaults: d) // migration already done

        XCTAssertEqual(try blobs(ctx).count, 1) // no duplicate blob for the same name
    }

    func testReconcileSkipsReferencedFileMissingLocally() throws {
        // An entry synced in from another device before its blob arrived: the
        // file isn't on disk yet, so there's nothing to upload (no empty blob).
        let ctx = try makeContext()
        let (store, root) = makeStore(); defer { try? FileManager.default.removeItem(at: root) }
        ctx.insert(DiaryEntry(text: "缺文件", imageFileNames: ["ghost.jpg"])); try ctx.save()

        MediaSyncService.reconcile(context: ctx, fileStore: store, defaults: freshDefaults())

        XCTAssertTrue(try blobs(ctx).isEmpty)
    }

    // MARK: Download (synced blob → local file)

    func testReconcileMaterializesMissingLocalFile() throws {
        let ctx = try makeContext()
        let (store, root) = makeStore(); defer { try? FileManager.default.removeItem(at: root) }

        // A blob arrived from another device; its file isn't on this device yet.
        let name = "\(UUID().uuidString).m4a"
        ctx.insert(MediaBlob(name: name, kind: "audio", data: Data([0x09, 0x08])))
        ctx.insert(DiaryEntry(text: "远端来的录音", audioFileName: name, audioDuration: 2))
        try ctx.save()
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.audioURL(name).path))

        MediaSyncService.reconcile(context: ctx, fileStore: store, defaults: freshDefaults())

        XCTAssertEqual(try Data(contentsOf: store.audioURL(name)), Data([0x09, 0x08]))
        XCTAssertEqual(try blobs(ctx).count, 1) // materializing doesn't re-upload
    }

    // MARK: Resurrection guard (the core race the design must survive)

    func testReconcileDoesNotResurrectDeletedBlob() throws {
        let ctx = try makeContext()
        let (store, root) = makeStore(); defer { try? FileManager.default.removeItem(at: root) }
        let imgName = try store.saveImage(image())
        let e = DiaryEntry(text: "会被删", imageFileNames: [imgName])
        ctx.insert(e); try ctx.save()

        let d = freshDefaults()
        MediaSyncService.reconcile(context: ctx, fileStore: store, defaults: d) // migration uploads, flag set
        XCTAssertEqual(try blobs(ctx).count, 1)

        // Simulate the remote blob-deletion arriving BEFORE the entry-deletion:
        // blob gone, but the entry (and its local file) still present here.
        for b in try blobs(ctx) { ctx.delete(b) }
        try ctx.save()

        MediaSyncService.reconcile(context: ctx, fileStore: store, defaults: d)

        XCTAssertTrue(try blobs(ctx).isEmpty)                 // NOT re-uploaded
        XCTAssertNotNil(store.loadImage(imgName))             // entry still references it → file kept
    }

    // MARK: Orphan cleanup (settled deletion → reclaim local file)

    func testReconcileReclaimsOrphanFileReferencedByNothing() throws {
        let ctx = try makeContext()
        let (store, root) = makeStore(); defer { try? FileManager.default.removeItem(at: root) }

        // A file left behind after both its entry and blob were deleted elsewhere.
        let name = "orphan.jpg"
        try store.writeMedia(name: name, data: Data([0xFF, 0xD8, 0xFF]))
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.imageURL(name).path))

        MediaSyncService.reconcile(context: ctx, fileStore: store, defaults: freshDefaults())

        XCTAssertFalse(FileManager.default.fileExists(atPath: store.imageURL(name).path))
    }

    func testReconcileKeepsBlobBackedFileWithoutEntry() throws {
        // Blob arrived but its entry hasn't yet — the materialized file must be
        // kept (not mistaken for an orphan) so it's ready when the entry lands.
        let ctx = try makeContext()
        let (store, root) = makeStore(); defer { try? FileManager.default.removeItem(at: root) }
        let name = "\(UUID().uuidString).m4a"
        ctx.insert(MediaBlob(name: name, kind: "audio", data: Data([0x07])))
        try ctx.save()

        MediaSyncService.reconcile(context: ctx, fileStore: store, defaults: freshDefaults())

        XCTAssertTrue(FileManager.default.fileExists(atPath: store.audioURL(name).path))
        XCTAssertEqual(try blobs(ctx).count, 1)
    }

    // MARK: Cleanup on delete

    func testDeleteRemovesEntrysBlobs() throws {
        let ctx = try makeContext()
        let (store, root) = makeStore(); defer { try? FileManager.default.removeItem(at: root) }
        let imgName = try store.saveImage(image())
        let e = DiaryEntry(text: "待删", imageFileNames: [imgName])
        ctx.insert(e); try ctx.save()
        MediaSyncService.reconcile(context: ctx, fileStore: store, defaults: freshDefaults())
        XCTAssertEqual(try blobs(ctx).count, 1)

        try DiaryService.delete(e, from: ctx, fileStore: store)

        XCTAssertTrue(try blobs(ctx).isEmpty)          // synced copy dropped too
        XCTAssertNil(store.loadImage(imgName))          // local file dropped
    }

    func testSaveUploadsNewMediaAndDropsRemoved() throws {
        let ctx = try makeContext()
        let (store, root) = makeStore(); defer { try? FileManager.default.removeItem(at: root) }

        // Save an entry with one photo → a blob exists right after save.
        var draft = DiaryDraft()
        draft.text = "初次"
        draft.images = [.new(image(), UUID())]
        let saved = try DiaryService.save(draft, existing: nil, into: ctx, fileStore: store)
        XCTAssertEqual(try blobs(ctx).count, 1)
        let firstBlobName = try XCTUnwrap(try blobs(ctx).first?.name)
        XCTAssertEqual(saved.imageFileNames, [firstBlobName])

        // Edit: drop that photo → its blob is removed.
        var edit = DiaryDraft()
        edit.text = saved.text
        edit.images = []
        _ = try DiaryService.save(edit, existing: saved, into: ctx, fileStore: store)
        XCTAssertTrue(try blobs(ctx).isEmpty)
    }
}
