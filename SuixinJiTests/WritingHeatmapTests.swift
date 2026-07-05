import XCTest
@testable import SuixinJi

/// 写作热力图 (evolution). The contribution-grid logic is pure; verify counts,
/// levels, grid shape, and the future/window boundaries.
final class WritingHeatmapTests: XCTestCase {

    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        c.firstWeekday = 2 // Monday
        return c
    }()

    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
    }

    func testLevelBuckets() {
        XCTAssertEqual(WritingHeatmap.level(0), 0)
        XCTAssertEqual(WritingHeatmap.level(1), 1)
        XCTAssertEqual(WritingHeatmap.level(2), 2)
        XCTAssertEqual(WritingHeatmap.level(3), 3)
        XCTAssertEqual(WritingHeatmap.level(9), 4)   // 4+ saturates
    }

    func testCountsGroupByDay() {
        let entries = [
            DiaryEntry(diaryDate: day(2026, 7, 1), text: "a"),
            DiaryEntry(diaryDate: day(2026, 7, 1), text: "b"),   // same day → 2
            DiaryEntry(diaryDate: day(2026, 7, 2), text: "c")
        ]
        let counts = WritingHeatmap.counts(entries, calendar: calendar)
        XCTAssertEqual(counts[calendar.startOfDay(for: day(2026, 7, 1))], 2)
        XCTAssertEqual(counts[calendar.startOfDay(for: day(2026, 7, 2))], 1)
    }

    func testGridShapeIsWeeksBySeven() {
        let cols = WritingHeatmap.columns(from: [], today: day(2026, 7, 5), weeks: 53, calendar: calendar)
        XCTAssertEqual(cols.count, 53)
        XCTAssertTrue(cols.allSatisfy { $0.count == 7 })
    }

    func testLastColumnContainsToday() {
        let today = day(2026, 7, 5)
        let cols = WritingHeatmap.columns(from: [], today: today, weeks: 53, calendar: calendar)
        let last = try! XCTUnwrap(cols.last)
        let todayStart = calendar.startOfDay(for: today)
        XCTAssertTrue(last.contains { calendar.isDate($0.date, inSameDayAs: todayStart) })
    }

    func testFutureDaysFlaggedAfterToday() {
        // Wed 2026-07-01 as "today"; the current week (Mon-Sun) has Thu/Fri/Sat/Sun ahead.
        let today = day(2026, 7, 1)
        let cols = WritingHeatmap.columns(from: [], today: today, weeks: 4, calendar: calendar)
        let last = try! XCTUnwrap(cols.last)
        let todayStart = calendar.startOfDay(for: today)
        for cell in last {
            XCTAssertEqual(cell.isFuture, cell.date > todayStart)
        }
        XCTAssertTrue(last.contains { $0.isFuture })       // some days ahead exist
        XCTAssertTrue(last.contains { !$0.isFuture })      // and some are today-or-past
    }

    func testWrittenDaysCountsRealEntriesOnly() {
        let today = day(2026, 7, 5)
        let entries = [
            DiaryEntry(diaryDate: day(2026, 7, 1), text: "a"),
            DiaryEntry(diaryDate: day(2026, 7, 1), text: "b"),   // same day → still 1 written day
            DiaryEntry(diaryDate: day(2026, 6, 30), text: "c")
        ]
        let cols = WritingHeatmap.columns(from: entries, today: today, weeks: 53, calendar: calendar)
        XCTAssertEqual(WritingHeatmap.writtenDays(in: cols), 2)
    }

    func testEntriesOutsideWindowAreExcludedFromWrittenDays() {
        let today = day(2026, 7, 5)
        let old = DiaryEntry(diaryDate: day(2020, 1, 1), text: "太久以前")   // > 53 weeks ago
        let cols = WritingHeatmap.columns(from: [old], today: today, weeks: 53, calendar: calendar)
        XCTAssertEqual(WritingHeatmap.writtenDays(in: cols), 0)
    }
}
