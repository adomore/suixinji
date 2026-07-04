import XCTest
import SwiftData
import UIKit
@testable import SuixinJi

/// The persistence core (PRD §5.3, §9). Uses an in-memory SwiftData store and a
/// temp FileStore so create/update/delete + file cascade can be asserted exactly.
@MainActor
final class DiaryServiceTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!
    private var root: URL!
    private var store: FileStoreImpl!

    override func setUpWithError() throws {
        container = try ModelContainer(
            for: DiaryEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        context = ModelContext(container)
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("svc-test-\(UUID().uuidString)")
        store = FileStoreImpl(root: root)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func image() -> UIImage {
        let f = UIGraphicsImageRendererFormat.default(); f.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: 60, height: 60), format: f).image { c in
            UIColor.orange.setFill(); c.fill(CGRect(x: 0, y: 0, width: 60, height: 60))
        }
    }

    private func tempAudio() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("rec-\(UUID().uuidString).m4a")
        try Data([0x1, 0x2, 0x3]).write(to: url)
        return url
    }

    private func allEntries() throws -> [DiaryEntry] {
        try context.fetch(FetchDescriptor<DiaryEntry>())
    }

    // MARK: Create

    func testCreateTextEntryInsertsAndPersists() throws {
        let draft = DiaryDraft(text: "今天去看了朝霞", diaryDate: Date())
        let saved = try DiaryService.save(draft, existing: nil, into: context, fileStore: store)

        XCTAssertEqual(saved.text, "今天去看了朝霞")
        XCTAssertEqual(try allEntries().count, 1)
    }

    func testCreateWithImagesWritesFiles() throws {
        let draft = DiaryDraft(
            text: "配图",
            images: [.new(image(), UUID()), .new(image(), UUID())]
        )
        let saved = try DiaryService.save(draft, existing: nil, into: context, fileStore: store)

        XCTAssertEqual(saved.imageFileNames.count, 2)
        for name in saved.imageFileNames {
            XCTAssertTrue(FileManager.default.fileExists(atPath: store.imageURL(name).path))
        }
    }

    func testCreateWithNewAudioAdoptsTempFile() throws {
        let temp = try tempAudio()
        let draft = DiaryDraft(text: "语音", audio: .new(temp, 12.3))
        let saved = try DiaryService.save(draft, existing: nil, into: context, fileStore: store)

        let name = try XCTUnwrap(saved.audioFileName)
        XCTAssertTrue(name.hasSuffix(".m4a"))
        XCTAssertEqual(saved.audioDuration ?? 0, 12.3, accuracy: 0.001)
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.audioURL(name).path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: temp.path))
    }

    // MARK: Update

    func testEditUpdatesTextWithoutDuplicating() throws {
        let created = try DiaryService.save(DiaryDraft(text: "原文"), existing: nil, into: context, fileStore: store)
        _ = try DiaryService.save(DiaryDraft(text: "改后"), existing: created, into: context, fileStore: store)

        let all = try allEntries()
        XCTAssertEqual(all.count, 1, "editing must not insert a new row")
        XCTAssertEqual(all.first?.text, "改后")
    }

    func testEditRemovingAnImageDeletesThatFile() throws {
        // Start with two images.
        let created = try DiaryService.save(
            DiaryDraft(images: [.new(image(), UUID()), .new(image(), UUID())]),
            existing: nil, into: context, fileStore: store
        )
        let kept = created.imageFileNames[0]
        let removed = created.imageFileNames[1]

        // Re-save keeping only the first (as an existing reference).
        _ = try DiaryService.save(
            DiaryDraft(images: [.existing(kept)]),
            existing: created, into: context, fileStore: store
        )

        XCTAssertEqual(created.imageFileNames, [kept])
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.imageURL(kept).path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.imageURL(removed).path),
                       "dropped image file must be deleted")
    }

    func testReplacingAudioDeletesOldFile() throws {
        let created = try DiaryService.save(
            DiaryDraft(audio: .new(try tempAudio(), 5)),
            existing: nil, into: context, fileStore: store
        )
        let oldName = try XCTUnwrap(created.audioFileName)

        _ = try DiaryService.save(
            DiaryDraft(audio: .new(try tempAudio(), 8)),
            existing: created, into: context, fileStore: store
        )
        let newName = try XCTUnwrap(created.audioFileName)

        XCTAssertNotEqual(oldName, newName)
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.audioURL(oldName).path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.audioURL(newName).path))
        XCTAssertEqual(created.audioDuration ?? 0, 8, accuracy: 0.001)
    }

    func testRemovingAudioClearsFieldsAndFile() throws {
        let created = try DiaryService.save(
            DiaryDraft(text: "有录音", audio: .new(try tempAudio(), 5)),
            existing: nil, into: context, fileStore: store
        )
        let name = try XCTUnwrap(created.audioFileName)

        _ = try DiaryService.save(
            DiaryDraft(text: "有录音", audio: nil),
            existing: created, into: context, fileStore: store
        )

        XCTAssertNil(created.audioFileName)
        XCTAssertNil(created.audioDuration)
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.audioURL(name).path))
    }

    func testKeepingExistingAudioIsPreserved() throws {
        let created = try DiaryService.save(
            DiaryDraft(audio: .new(try tempAudio(), 9)),
            existing: nil, into: context, fileStore: store
        )
        let name = try XCTUnwrap(created.audioFileName)

        _ = try DiaryService.save(
            DiaryDraft(text: "改文字", audio: .existing(name, 9)),
            existing: created, into: context, fileStore: store
        )

        XCTAssertEqual(created.audioFileName, name)
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.audioURL(name).path))
    }

    // MARK: Delete (cascade)

    func testDeleteRemovesRecordAndAllFiles() throws {
        let created = try DiaryService.save(
            DiaryDraft(
                text: "全都有",
                images: [.new(image(), UUID())],
                audio: .new(try tempAudio(), 7)
            ),
            existing: nil, into: context, fileStore: store
        )
        let img = created.imageFileNames[0]
        let aud = try XCTUnwrap(created.audioFileName)

        try DiaryService.delete(created, from: context, fileStore: store)

        XCTAssertEqual(try allEntries().count, 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.imageURL(img).path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.audioURL(aud).path))
    }

    // A file-write failure mid-save must roll back: no phantom entry, no orphan
    // files (regression for the "empty entry autosaved on error" bug).
    func testCreateRollsBackOnFileFailure() throws {
        let missingAudio = FileManager.default.temporaryDirectory
            .appendingPathComponent("does-not-exist-\(UUID().uuidString).m4a")
        let draft = DiaryDraft(
            text: "会失败", images: [.new(image(), UUID())],
            audio: .new(missingAudio, 5) // adoptAudio will throw (no temp file)
        )
        XCTAssertThrowsError(try DiaryService.save(draft, existing: nil, into: context, fileStore: store))
        XCTAssertEqual(try allEntries().count, 0, "no phantom entry may persist")
        let leftover = (try? FileManager.default.contentsOfDirectory(atPath: store.imagesDir.path)) ?? []
        XCTAssertTrue(leftover.isEmpty, "the image written before the failure must be rolled back")
    }

    func testUpdatedAtAdvancesOnSave() throws {
        let created = try DiaryService.save(DiaryDraft(text: "a"), existing: nil, into: context, fileStore: store)
        let first = created.updatedAt
        Thread.sleep(forTimeInterval: 0.01)
        _ = try DiaryService.save(DiaryDraft(text: "b"), existing: created, into: context, fileStore: store)
        XCTAssertGreaterThan(created.updatedAt, first)
    }
}
