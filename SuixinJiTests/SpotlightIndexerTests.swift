import XCTest
import CoreSpotlight
@testable import SuixinJi

/// Spotlight indexing (evolution). Tests the pure item-building; the actual
/// `CSSearchableIndex` calls are best-effort side effects verified on device.
final class SpotlightIndexerTests: XCTestCase {

    func testItemUsesEntryIDAndDomain() {
        let e = DiaryEntry(text: "内容")
        let item = SpotlightIndexer.makeItem(for: e)
        XCTAssertEqual(item.uniqueIdentifier, e.id.uuidString)
        XCTAssertEqual(item.domainIdentifier, SpotlightIndexer.domain)
        XCTAssertEqual(item.attributeSet.contentDescription, "内容")
    }

    func testTitleUsesFirstLineSnippetOnly() {
        let e = DiaryEntry(text: "今天很开心\n第二行不该出现")
        let title = SpotlightIndexer.title(for: e)
        XCTAssertTrue(title.contains("今天很开心"))
        XCTAssertFalse(title.contains("第二行"))
    }

    func testTitleFallsBackToDateForEmptyText() {
        let e = DiaryEntry(text: "")
        let title = SpotlightIndexer.title(for: e)
        XCTAssertFalse(title.isEmpty)
        XCTAssertFalse(title.contains("·")) // no snippet separator when there's no text
    }

    func testKeywordsIncludeTagsMoodPlaceWeather() {
        let e = DiaryEntry(text: "x", mood: "😊", weatherText: "晴 26°",
                           tags: ["旅行", "美食"], locationName: "杭州西湖")
        let kw = SpotlightIndexer.keywords(for: e)
        XCTAssertTrue(kw.contains("旅行"))
        XCTAssertTrue(kw.contains("美食"))
        XCTAssertTrue(kw.contains("😊"))
        XCTAssertTrue(kw.contains("杭州西湖"))
        XCTAssertTrue(kw.contains("晴 26°"))
    }

    func testEmptyTextEntryGetsMediaPlaceholderDescription() {
        let e = DiaryEntry(text: "", imageFileNames: ["a.jpg"], audioFileName: "b.m4a")
        let item = SpotlightIndexer.makeItem(for: e)
        XCTAssertEqual(item.attributeSet.contentDescription, "图片 · 录音")
    }
}
