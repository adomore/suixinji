import XCTest
@testable import SuixinJi

/// 每日灵感 + 写作习惯 engines (evolution). Pure, deterministic.
final class WritingPromptsTests: XCTestCase {
    private let cal = Calendar(identifier: .gregorian)

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d))!
    }

    // MARK: Prompt of the day

    func testPromptStableWithinSameDay() {
        let morning = cal.date(from: DateComponents(year: 2026, month: 7, day: 5, hour: 8))!
        let night = cal.date(from: DateComponents(year: 2026, month: 7, day: 5, hour: 23))!
        XCTAssertEqual(WritingPrompts.ofTheDay(morning, calendar: cal),
                       WritingPrompts.ofTheDay(night, calendar: cal))
    }

    func testPromptRotatesDayToDay() {
        // Over `all.count` consecutive days every prompt appears exactly once.
        let n = WritingPrompts.all.count
        let start = date(2026, 1, 1)
        var seen = Set<String>()
        for offset in 0..<n {
            let d = cal.date(byAdding: .day, value: offset, to: start)!
            seen.insert(WritingPrompts.ofTheDay(d, calendar: cal))
        }
        XCTAssertEqual(seen.count, n) // full, non-repeating rotation
    }

    func testPromptAlwaysFromCuratedList() {
        let d = date(2026, 3, 14)
        XCTAssertTrue(WritingPrompts.all.contains(WritingPrompts.ofTheDay(d, calendar: cal)))
    }

    // MARK: Weekly habit

    func testRecentDaysReturnsSevenOldestFirstEndingToday() {
        let today = date(2026, 7, 5)
        let days = WritingHabit.recentDays([], today: today, calendar: cal)
        XCTAssertEqual(days.count, 7)
        XCTAssertEqual(days.first?.date, date(2026, 6, 29)) // 6 days before
        XCTAssertEqual(days.last?.date, date(2026, 7, 5))   // today
        XCTAssertTrue(days.allSatisfy { !$0.written })
    }

    func testRecentDaysFlagsWrittenDays() {
        let today = date(2026, 7, 5)
        let e1 = DiaryEntry(diaryDate: date(2026, 7, 5), text: "今天")
        let e2 = DiaryEntry(diaryDate: date(2026, 7, 2), text: "前几天")
        let outside = DiaryEntry(diaryDate: date(2026, 6, 1), text: "很久以前") // outside window
        let days = WritingHabit.recentDays([e1, e2, outside], today: today, calendar: cal)
        let written = days.filter(\.written).map(\.date)
        XCTAssertEqual(Set(written), [date(2026, 7, 5), date(2026, 7, 2)])
    }

    func testMultipleEntriesSameDayCountOnce() {
        let today = date(2026, 7, 5)
        let a = DiaryEntry(diaryDate: date(2026, 7, 5), text: "a")
        let b = DiaryEntry(diaryDate: date(2026, 7, 5), text: "b")
        let days = WritingHabit.recentDays([a, b], today: today, calendar: cal)
        XCTAssertEqual(days.filter(\.written).count, 1)
    }
}
