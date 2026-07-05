import XCTest
@testable import SuixinJi

/// 引导式模板日记 (evolution). The template catalog is pure data; verify it's
/// well-formed so the editor can rely on it.
final class JournalTemplateTests: XCTestCase {

    func testCatalogIsNonEmpty() {
        XCTAssertFalse(JournalTemplate.all.isEmpty)
    }

    func testEveryTemplateIsWellFormed() {
        for t in JournalTemplate.all {
            XCTAssertFalse(t.id.isEmpty, "empty id")
            XCTAssertFalse(t.title.isEmpty, "empty title for \(t.id)")
            XCTAssertFalse(t.symbol.isEmpty, "empty symbol for \(t.id)")
            XCTAssertFalse(t.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                           "empty body for \(t.id)")
        }
    }

    func testIDsAreUnique() {
        let ids = JournalTemplate.all.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count, "template ids must be unique")
    }

    func testBodiesLeadWithAMarkdownHeading() {
        // Each skeleton opens with a "## 标题" so the detail view renders it as a heading.
        for t in JournalTemplate.all {
            XCTAssertTrue(t.body.hasPrefix("## "), "\(t.id) body should start with a Markdown heading")
        }
    }

    func testLookupByID() {
        let first = JournalTemplate.all[0]
        XCTAssertEqual(JournalTemplate.template(id: first.id), first)
        XCTAssertNil(JournalTemplate.template(id: "does-not-exist"))
    }

    /// A template body counts as content, so saving is enabled after picking one.
    func testTemplateBodyCountsAsDraftContent() {
        for t in JournalTemplate.all {
            var draft = DiaryDraft()
            draft.text = t.body
            XCTAssertTrue(draft.hasContent, "\(t.id) should make the draft saveable")
        }
    }
}
