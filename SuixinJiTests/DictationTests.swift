import XCTest
@testable import SuixinJi

/// At-caret dictation insertion (PRD §3.2 F2). All offsets are UTF-16.
final class DictationTests: XCTestCase {

    func testInsertsAtCaretInTheMiddle() {
        // caret between "前面" and "后面"
        let r = Dictation.insert(into: "前面后面", anchor: 2, previousChunkLength: 0, recognized: "语音")
        XCTAssertEqual(r.text, "前面语音后面")
        XCTAssertEqual(r.caret, 4)       // after the inserted chunk
        XCTAssertEqual(r.chunkLength, 2)
    }

    func testGrowingResultReplacesPreviousChunkInPlace() {
        // First partial "语音" already inserted at anchor 2 (chunk length 2);
        // the next partial "语音识别" must replace it, not append.
        let r = Dictation.insert(into: "前面语音后面", anchor: 2, previousChunkLength: 2, recognized: "语音识别")
        XCTAssertEqual(r.text, "前面语音识别后面")
        XCTAssertEqual(r.caret, 6)
        XCTAssertEqual(r.chunkLength, 4)
    }

    func testInsertAtStart() {
        let r = Dictation.insert(into: "abc", anchor: 0, previousChunkLength: 0, recognized: "X")
        XCTAssertEqual(r.text, "Xabc")
        XCTAssertEqual(r.caret, 1)
    }

    func testInsertAtEnd() {
        let r = Dictation.insert(into: "abc", anchor: 3, previousChunkLength: 0, recognized: "X")
        XCTAssertEqual(r.text, "abcX")
        XCTAssertEqual(r.caret, 4)
    }

    func testAnchorBeyondLengthIsClamped() {
        let r = Dictation.insert(into: "ab", anchor: 99, previousChunkLength: 0, recognized: "X")
        XCTAssertEqual(r.text, "abX")
        XCTAssertEqual(r.caret, 3)
    }

    func testPreviousChunkLongerThanRemainingIsClamped() {
        let r = Dictation.insert(into: "ab", anchor: 0, previousChunkLength: 99, recognized: "Z")
        XCTAssertEqual(r.text, "Z")     // replaced everything from anchor
        XCTAssertEqual(r.caret, 1)
    }

    func testEmojiChunkUsesUTF16Length() {
        let r = Dictation.insert(into: "", anchor: 0, previousChunkLength: 0, recognized: "😀")
        XCTAssertEqual(r.text, "😀")
        XCTAssertEqual(r.chunkLength, 2) // one emoji = 2 UTF-16 units
        XCTAssertEqual(r.caret, 2)
    }
}
