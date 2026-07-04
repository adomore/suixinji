import XCTest
import UIKit
@testable import SuixinJi

/// Sandbox file storage (PRD §5.3): compression, round-trips, and deletion.
/// Each test gets an isolated temp root so nothing touches the real Documents dir.
final class FileStoreTests: XCTestCase {

    private var root: URL!
    private var store: FileStoreImpl!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("filestore-test-\(UUID().uuidString)")
        store = FileStoreImpl(root: root)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    // Solid-color test image of a given pixel size.
    private func image(_ w: CGFloat, _ h: CGFloat) -> UIImage {
        let fmt = UIGraphicsImageRendererFormat.default(); fmt.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: w, height: h), format: fmt).image { ctx in
            UIColor.systemOrange.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        }
    }

    func testCreatesDirectories() {
        var isDir: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.imagesDir.path, isDirectory: &isDir) && isDir.boolValue)
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.audiosDir.path, isDirectory: &isDir) && isDir.boolValue)
    }

    func testSaveImageReturnsJPGNameAndPersists() throws {
        let name = try store.saveImage(image(100, 80))
        XCTAssertTrue(name.hasSuffix(".jpg"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.imageURL(name).path))
        XCTAssertNotNil(store.loadImage(name))
    }

    func testSaveImageCompressesLongEdgeTo2048() throws {
        let name = try store.saveImage(image(4000, 3000)) // huge original (F4)
        let reloaded = try XCTUnwrap(store.loadImage(name))
        XCTAssertEqual(max(reloaded.size.width, reloaded.size.height), 2048, accuracy: 1)
        XCTAssertEqual(reloaded.size.height, 1536, accuracy: 1) // aspect preserved
    }

    func testDownscaleIsNoOpWhenWithinBounds() {
        let small = image(500, 400)
        let out = FileStoreImpl.downscale(small, maxEdge: 2048)
        XCTAssertEqual(out.size, small.size)
    }

    func testAdoptAudioMovesTempFile() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("rec-\(UUID().uuidString).m4a")
        try Data([0x00, 0x01, 0x02]).write(to: temp)

        let name = try store.adoptAudio(tempURL: temp)
        XCTAssertTrue(name.hasSuffix(".m4a"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.audioURL(name).path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: temp.path), "temp is moved, not copied")
    }

    func testDeleteImageAndAudio() throws {
        let img = try store.saveImage(image(50, 50))
        store.deleteImage(img)
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.imageURL(img).path))

        let temp = FileManager.default.temporaryDirectory.appendingPathComponent("t-\(UUID().uuidString).m4a")
        try Data([0x00]).write(to: temp)
        let aud = try store.adoptAudio(tempURL: temp)
        store.deleteAudio(aud)
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.audioURL(aud).path))
    }

    func testDeleteFilesForEntryRemovesEverything() throws {
        let img1 = try store.saveImage(image(40, 40))
        let img2 = try store.saveImage(image(40, 40))
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent("t-\(UUID().uuidString).m4a")
        try Data([0x00]).write(to: temp)
        let aud = try store.adoptAudio(tempURL: temp)

        let entry = DiaryEntry(imageFileNames: [img1, img2], audioFileName: aud, audioDuration: 5)
        store.deleteFiles(for: entry)

        XCTAssertFalse(FileManager.default.fileExists(atPath: store.imageURL(img1).path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.imageURL(img2).path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.audioURL(aud).path))
    }

    func testLoadMissingImageReturnsNil() {
        XCTAssertNil(store.loadImage("does-not-exist.jpg"))
    }
}
