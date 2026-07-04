import XCTest
import UIKit
@testable import SuixinJi

/// Draft value types used by the editor.
final class DiaryDraftTests: XCTestCase {

    func testDraftHasContentRules() {
        XCTAssertFalse(DiaryDraft().hasContent)
        XCTAssertFalse(DiaryDraft(text: "   ").hasContent)
        XCTAssertTrue(DiaryDraft(text: "文字").hasContent)
        XCTAssertTrue(DiaryDraft(images: [.existing("a.jpg")]).hasContent)
        XCTAssertTrue(DiaryDraft(audio: .existing("a.m4a", 3)).hasContent)
    }

    func testEditorImageIdentity() {
        XCTAssertEqual(EditorImage.existing("x.jpg").id, "x.jpg")
        let uuid = UUID()
        let img = UIGraphicsImageRenderer(size: .init(width: 1, height: 1)).image { _ in }
        XCTAssertEqual(EditorImage.new(img, uuid).id, uuid.uuidString)
    }

    func testEditorImageEquatableById() {
        XCTAssertEqual(EditorImage.existing("a.jpg"), EditorImage.existing("a.jpg"))
        XCTAssertNotEqual(EditorImage.existing("a.jpg"), EditorImage.existing("b.jpg"))
    }

    func testDraftAudioDuration() {
        XCTAssertEqual(DraftAudio.existing("a.m4a", 12).duration, 12)
        let url = URL(fileURLWithPath: "/tmp/x.m4a")
        XCTAssertEqual(DraftAudio.new(url, 34).duration, 34)
    }
}
