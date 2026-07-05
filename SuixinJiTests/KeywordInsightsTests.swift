import XCTest
@testable import SuixinJi

/// 关键词洞察 (evolution). The counting/filtering is pure; tokenization is exercised
/// on English (deterministic word segmentation) plus direct token lists.
final class KeywordInsightsTests: XCTestCase {

    func testRankCountsAndOrders() {
        let tokens = ["cat", "cat", "cat", "dog", "dog", "bird"]
        let ranked = KeywordInsights.rank(tokens)
        XCTAssertEqual(ranked.map(\.word), ["cat", "dog", "bird"])   // by count desc
        XCTAssertEqual(ranked.first?.count, 3)
    }

    func testTiesBreakAlphabetically() {
        let ranked = KeywordInsights.rank(["banana", "apple", "banana", "apple"])
        XCTAssertEqual(ranked.map(\.word), ["apple", "banana"])      // equal counts → a < b
    }

    func testStopwordsAndShortTokensDropped() {
        let ranked = KeywordInsights.rank(["the", "the", "a", "x", "旅行", "旅行", "的", "什么"])
        // "the"/"什么" are stopwords; "a"/"x"/"的" are one char → only "旅行" survives.
        XCTAssertEqual(ranked.map(\.word), ["旅行"])
        XCTAssertEqual(ranked.first?.count, 2)
    }

    func testPunctuationAndNumbersDropped() {
        XCTAssertFalse(KeywordInsights.isMeaningful("!!"))
        XCTAssertFalse(KeywordInsights.isMeaningful("123"))
        XCTAssertFalse(KeywordInsights.isMeaningful("🌿🌿"))
        XCTAssertTrue(KeywordInsights.isMeaningful("旅行"))
        XCTAssertTrue(KeywordInsights.isMeaningful("hello"))
    }

    func testCaseInsensitiveCounting() {
        let ranked = KeywordInsights.rank(["Hello", "hello", "HELLO"])
        XCTAssertEqual(ranked.count, 1)
        XCTAssertEqual(ranked.first?.word, "hello")
        XCTAssertEqual(ranked.first?.count, 3)
    }

    func testLimitCapsResults() {
        let tokens = ["alpha", "bravo", "charlie", "delta", "echo"]
        XCTAssertEqual(KeywordInsights.rank(tokens, limit: 3).count, 3)
    }

    func testTopWordsOverEntriesEnglish() {
        let entries = [
            DiaryEntry(text: "coffee coffee walk"),
            DiaryEntry(text: "coffee walk walk walk")
        ]
        let top = KeywordInsights.topWords(from: entries, limit: 5)
        XCTAssertEqual(top.first?.word, "walk")   // walk×4 > coffee×3
        XCTAssertEqual(top.first?.count, 4)
    }
}
