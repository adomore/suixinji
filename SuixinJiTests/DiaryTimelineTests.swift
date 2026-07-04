import XCTest
@testable import SuixinJi

/// Timeline year-month grouping (PRD §F5).
final class DiaryTimelineTests: XCTestCase {

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var c = DateComponents(); c.year = y; c.month = m; c.day = d; c.hour = 12
        return Calendar(identifier: .gregorian).date(from: c)!
    }

    func testEmptyProducesNoSections() {
        XCTAssertTrue(DiaryTimeline.sections(from: []).isEmpty)
    }

    func testSingleMonthGroupsTogether() {
        let entries = [
            DiaryEntry(diaryDate: date(2026, 7, 4)),
            DiaryEntry(diaryDate: date(2026, 7, 2)),
        ]
        let sections = DiaryTimeline.sections(from: entries)
        XCTAssertEqual(sections.count, 1)
        XCTAssertEqual(sections[0].key, "2026年7月")
        XCTAssertEqual(sections[0].entries.count, 2)
    }

    func testTwoMonthsSplitInOrder() {
        let jul1 = DiaryEntry(diaryDate: date(2026, 7, 4))
        let jul2 = DiaryEntry(diaryDate: date(2026, 7, 2))
        let jun = DiaryEntry(diaryDate: date(2026, 6, 28))
        let sections = DiaryTimeline.sections(from: [jul1, jul2, jun])
        XCTAssertEqual(sections.map(\.key), ["2026年7月", "2026年6月"])
        XCTAssertEqual(sections[0].entries.count, 2)
        XCTAssertEqual(sections[1].entries.count, 1)
    }

    func testYearBoundary() {
        let sections = DiaryTimeline.sections(from: [
            DiaryEntry(diaryDate: date(2027, 1, 1)),
            DiaryEntry(diaryDate: date(2026, 12, 31)),
        ])
        XCTAssertEqual(sections.map(\.key), ["2027年1月", "2026年12月"])
    }

    /// A back-dated entry sandwiched between same-month entries yields its own
    /// contiguous section (order follows the input = createdAt order).
    func testNonContiguousSameMonthMakesSeparateSections() {
        let sections = DiaryTimeline.sections(from: [
            DiaryEntry(diaryDate: date(2026, 7, 10)),
            DiaryEntry(diaryDate: date(2026, 6, 20)),
            DiaryEntry(diaryDate: date(2026, 7, 1)),
        ])
        XCTAssertEqual(sections.map(\.key), ["2026年7月", "2026年6月", "2026年7月"])
    }
}
