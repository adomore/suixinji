import XCTest
@testable import SuixinJi

/// 整本导出 · 电子书 (evolution). The chapter grouping is pure; verify month
/// chapters, chronological order, titles, and the cover date range.
final class BookExportTests: XCTestCase {

    private var calendar = Calendar(identifier: .gregorian)

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
    }

    func testChaptersGroupByMonthChronologically() {
        let entries = [
            DiaryEntry(diaryDate: date(2026, 7, 5), text: "b"),
            DiaryEntry(diaryDate: date(2026, 6, 1), text: "a"),
            DiaryEntry(diaryDate: date(2026, 7, 20), text: "c")
        ]
        let chapters = BookExport.chapters(from: entries, calendar: calendar)
        XCTAssertEqual(chapters.map(\.key), ["2026-06", "2026-07"])  // oldest first
        XCTAssertEqual(chapters[0].title, "2026年6月")
        XCTAssertEqual(chapters[1].title, "2026年7月")
        XCTAssertEqual(chapters[0].entries.count, 1)
        XCTAssertEqual(chapters[1].entries.count, 2)
    }

    func testEntriesWithinChapterAreChronological() {
        let entries = [
            DiaryEntry(diaryDate: date(2026, 7, 20), text: "late"),
            DiaryEntry(diaryDate: date(2026, 7, 5), text: "early")
        ]
        let chapter = BookExport.chapters(from: entries, calendar: calendar)[0]
        XCTAssertEqual(chapter.entries.map(\.text), ["early", "late"])
    }

    func testEmptyGivesNoChapters() {
        XCTAssertTrue(BookExport.chapters(from: [], calendar: calendar).isEmpty)
    }

    func testDateRangeSpansFirstToLast() {
        let entries = [
            DiaryEntry(diaryDate: date(2025, 1, 3), text: "x"),
            DiaryEntry(diaryDate: date(2026, 7, 5), text: "y")
        ]
        XCTAssertEqual(BookExport.dateRange(of: entries, calendar: calendar), "2025年1月 – 2026年7月")
    }

    func testDateRangeSingleMonthCollapses() {
        let entries = [
            DiaryEntry(diaryDate: date(2026, 7, 1), text: "x"),
            DiaryEntry(diaryDate: date(2026, 7, 9), text: "y")
        ]
        XCTAssertEqual(BookExport.dateRange(of: entries, calendar: calendar), "2026年7月")
    }
}
