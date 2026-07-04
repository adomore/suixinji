import XCTest
@testable import SuixinJi

/// DiaryEntry model rules (PRD §5.2, F1 save rule).
final class DiaryEntryTests: XCTestCase {

    func testDefaultInitialization() {
        let entry = DiaryEntry()
        XCTAssertEqual(entry.text, "")
        XCTAssertNil(entry.mood)
        XCTAssertTrue(entry.imageFileNames.isEmpty)
        XCTAssertNil(entry.audioFileName)
        XCTAssertNil(entry.audioDuration)
        XCTAssertFalse(entry.hasAudio)
        // createdAt / diaryDate / updatedAt default to "now".
        XCTAssertEqual(entry.createdAt.timeIntervalSinceNow, 0, accuracy: 2)
        XCTAssertEqual(entry.diaryDate.timeIntervalSinceNow, 0, accuracy: 2)
    }

    func testHasContentIsFalseWhenEmpty() {
        XCTAssertFalse(DiaryEntry(text: "").hasContent)
        XCTAssertFalse(DiaryEntry(text: "   \n\t ").hasContent, "whitespace-only is empty")
    }

    func testHasContentWithText() {
        XCTAssertTrue(DiaryEntry(text: "今天去看了朝霞").hasContent)
    }

    func testHasContentWithImageOnly() {
        XCTAssertTrue(DiaryEntry(text: "", imageFileNames: ["a.jpg"]).hasContent)
    }

    func testHasContentWithAudioOnly() {
        let e = DiaryEntry(text: "", audioFileName: "a.m4a", audioDuration: 3)
        XCTAssertTrue(e.hasContent)
        XCTAssertTrue(e.hasAudio)
    }

    func testCustomDiaryDateIsPreserved() {
        let past = Date(timeIntervalSince1970: 1_000_000)
        let e = DiaryEntry(diaryDate: past, text: "补记")
        XCTAssertEqual(e.diaryDate, past)
    }
}
