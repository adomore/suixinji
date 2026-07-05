import XCTest
@testable import SuixinJi

/// 回顾 · 记忆 engine: On-This-Day lookup, streak milestones, monthly recap.
final class MemoriesTests: XCTestCase {

    private let cal = Calendar(identifier: .gregorian)

    private func date(_ y: Int, _ m: Int, _ d: Int, hour: Int = 12) -> Date {
        var c = DateComponents(); c.year = y; c.month = m; c.day = d; c.hour = hour
        return cal.date(from: c)!
    }

    // MARK: On This Day

    func testOnThisDayMatchesSameMonthDayEarlierYears() {
        let today = date(2026, 7, 5)
        let entries = [
            DiaryEntry(diaryDate: date(2025, 7, 5), text: "去年"),
            DiaryEntry(diaryDate: date(2024, 7, 5), text: "前年"),
            DiaryEntry(diaryDate: date(2025, 7, 6), text: "差一天"),
            DiaryEntry(diaryDate: date(2026, 7, 5), text: "今天，排除"),
        ]
        let memories = Memories.onThisDay(entries, today: today, calendar: cal)
        XCTAssertEqual(memories.map(\.text), ["去年", "前年"]) // newest first, today excluded
    }

    func testOnThisDayEmptyWhenNoMatch() {
        let today = date(2026, 7, 5)
        let entries = [DiaryEntry(diaryDate: date(2025, 8, 1))]
        XCTAssertTrue(Memories.onThisDay(entries, today: today, calendar: cal).isEmpty)
    }

    func testYearsAgo() {
        XCTAssertEqual(Memories.yearsAgo(date(2024, 7, 5), from: date(2026, 7, 5), calendar: cal), 2)
        XCTAssertEqual(Memories.yearsAgo(date(2025, 7, 5), from: date(2026, 7, 5), calendar: cal), 1)
    }

    // MARK: Milestones

    func testNextMilestone() {
        XCTAssertEqual(Memories.nextMilestone(currentStreak: 0), 7)
        XCTAssertEqual(Memories.nextMilestone(currentStreak: 7), 30)
        XCTAssertEqual(Memories.nextMilestone(currentStreak: 200), 365)
        XCTAssertNil(Memories.nextMilestone(currentStreak: 365))
        XCTAssertNil(Memories.nextMilestone(currentStreak: 500))
    }

    func testAchievedMilestones() {
        XCTAssertEqual(Memories.achievedMilestones(longestStreak: 0), [])
        XCTAssertEqual(Memories.achievedMilestones(longestStreak: 30), [7, 30])
        XCTAssertEqual(Memories.achievedMilestones(longestStreak: 400), [7, 30, 100, 365])
    }

    // MARK: Monthly recap

    func testMonthlyRecapAggregatesTheMonthOnly() {
        let entries = [
            DiaryEntry(diaryDate: date(2026, 7, 1), mood: "😊", imageFileNames: ["a.jpg"]),
            DiaryEntry(diaryDate: date(2026, 7, 1), mood: "😊"),                 // same day
            DiaryEntry(diaryDate: date(2026, 7, 20), mood: "😢", audioFileName: "a.m4a"),
            DiaryEntry(diaryDate: date(2026, 6, 30), mood: "😊"),                 // other month
        ]
        let recap = MonthlyRecap.build(from: entries, month: date(2026, 7, 15), calendar: cal)
        XCTAssertEqual(recap.monthKey, "2026年7月")
        XCTAssertEqual(recap.entryCount, 3)
        XCTAssertEqual(recap.daysWritten, 2)     // Jul 1 and Jul 20
        XCTAssertEqual(recap.topMood, "😊")      // 2×😊 vs 1×😢
        XCTAssertEqual(recap.withPhotos, 1)
        XCTAssertEqual(recap.withAudio, 1)
        XCTAssertFalse(recap.isEmpty)
    }

    func testEmptyMonthlyRecap() {
        let recap = MonthlyRecap.build(from: [], month: date(2026, 7, 15), calendar: cal)
        XCTAssertTrue(recap.isEmpty)
        XCTAssertNil(recap.topMood)
    }
}
