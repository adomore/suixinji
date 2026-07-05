import XCTest
@testable import SuixinJi

/// 富文本 Markdown block parser (evolution). Pure line classification + preview.
final class MarkdownParserTests: XCTestCase {

    func testHeadings() {
        XCTAssertEqual(MarkdownParser.classify("# H1"), .heading(1, "H1"))
        XCTAssertEqual(MarkdownParser.classify("## H2"), .heading(2, "H2"))
        XCTAssertEqual(MarkdownParser.classify("### H3"), .heading(3, "H3"))
        XCTAssertEqual(MarkdownParser.classify("#NoSpace"), .paragraph("#NoSpace")) // needs a space
    }

    func testBullets() {
        XCTAssertEqual(MarkdownParser.classify("- a"), .bullet("a"))
        XCTAssertEqual(MarkdownParser.classify("* b"), .bullet("b"))
        XCTAssertEqual(MarkdownParser.classify("• c"), .bullet("c"))
    }

    func testOrdered() {
        XCTAssertEqual(MarkdownParser.classify("1. first"), .ordered("1", "first"))
        XCTAssertEqual(MarkdownParser.classify("10. tenth"), .ordered("10", "tenth"))
        XCTAssertEqual(MarkdownParser.classify("1.nospace"), .paragraph("1.nospace"))
    }

    func testQuoteAndDivider() {
        XCTAssertEqual(MarkdownParser.classify("> hi"), .quote("hi"))
        XCTAssertEqual(MarkdownParser.classify(">"), .quote(""))
        XCTAssertEqual(MarkdownParser.classify("---"), .divider)
        XCTAssertEqual(MarkdownParser.classify("***"), .divider)
        XCTAssertEqual(MarkdownParser.classify("--"), .paragraph("--"))     // too short
        XCTAssertEqual(MarkdownParser.classify("---x"), .paragraph("---x")) // mixed
    }

    func testParagraphAndBlank() {
        XCTAssertEqual(MarkdownParser.classify("hello"), .paragraph("hello"))
        XCTAssertEqual(MarkdownParser.classify(""), .paragraph(""))
        XCTAssertEqual(MarkdownParser.classify("   "), .paragraph("")) // whitespace-only → blank
    }

    func testBlocksPreservesLineOrder() {
        let blocks = MarkdownParser.blocks(from: "# 标题\n\n- a\n- b")
        XCTAssertEqual(blocks, [.heading(1, "标题"), .paragraph(""), .bullet("a"), .bullet("b")])
    }

    func testPlainPreviewStripsMarkers() {
        let preview = MarkdownParser.plainPreview("# 标题\n**粗体**内容\n- 项目\n---")
        XCTAssertFalse(preview.contains("#"))
        XCTAssertFalse(preview.contains("*"))
        XCTAssertFalse(preview.contains("-"))
        XCTAssertTrue(preview.contains("标题"))
        XCTAssertTrue(preview.contains("粗体"))
        XCTAssertTrue(preview.contains("项目"))
    }

    func testPlainPreviewOfPlainTextUnchanged() {
        XCTAssertEqual(MarkdownParser.plainPreview("就是普通的一句话"), "就是普通的一句话")
    }
}
