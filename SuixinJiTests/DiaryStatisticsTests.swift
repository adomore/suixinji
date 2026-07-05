import XCTest
@testable import SuixinJi

/// Insights aggregation, especially the streak math (deterministic `today`).
final class DiaryStatisticsTests: XCTestCase {

    private let cal = Calendar(identifier: .gregorian)

    /// Fixed "today" = 2026-07-15 12:00, so streak tests don't depend on wall clock.
    private func today() -> Date {
        var c = DateComponents(); c.year = 2026; c.month = 7; c.day = 15; c.hour = 12
        return cal.date(from: c)!
    }

    private func day(_ offset: Int, hour: Int = 9) -> Date {
        cal.date(byAdding: .day, value: offset, to: cal.date(bySettingHour: hour, minute: 0, second: 0, of: today())!)!
    }

    private func entry(daysAgo: Int, mood: String? = nil, images: [String] = [], audio: String? = nil) -> DiaryEntry {
        DiaryEntry(diaryDate: day(-daysAgo), mood: mood, imageFileNames: images, audioFileName: audio)
    }

    func testEmptyStatsAreZero() {
        let s = DiaryStatistics.compute(from: [], calendar: cal, today: today())
        XCTAssertEqual(s.totalEntries, 0)
        XCTAssertEqual(s.currentStreak, 0)
        XCTAssertEqual(s.longestStreak, 0)
        XCTAssertTrue(s.moods.isEmpty)
        XCTAssertTrue(s.months.isEmpty)
    }

    func testCurrentStreakCountsConsecutiveDaysUpToToday() {
        // today, -1, -2 written; -3 missing → streak 3.
        let s = DiaryStatistics.compute(
            from: [entry(daysAgo: 0), entry(daysAgo: 1), entry(daysAgo: 2), entry(daysAgo: 4)],
            calendar: cal, today: today())
        XCTAssertEqual(s.currentStreak, 3)
    }

    func testCurrentStreakGraceWhenTodayMissingButYesterdayWritten() {
        // No entry today; -1 and -2 written → streak stays alive at 2.
        let s = DiaryStatistics.compute(
            from: [entry(daysAgo: 1), entry(daysAgo: 2)], calendar: cal, today: today())
        XCTAssertEqual(s.currentStreak, 2)
    }

    func testCurrentStreakBrokenWhenGapExceedsGrace() {
        // Last entry was 2 days ago → beyond the 1-day grace → 0.
        let s = DiaryStatistics.compute(from: [entry(daysAgo: 2)], calendar: cal, today: today())
        XCTAssertEqual(s.currentStreak, 0)
    }

    func testMultipleEntriesSameDayCountAsOneStreakDay() {
        let s = DiaryStatistics.compute(
            from: [entry(daysAgo: 0), entry(daysAgo: 0), entry(daysAgo: 1)],
            calendar: cal, today: today())
        XCTAssertEqual(s.currentStreak, 2)
        XCTAssertEqual(s.daysWritten, 2)
        XCTAssertEqual(s.totalEntries, 3)
    }

    func testLongestStreakFindsBestRunAnywhere() {
        // A 4-day run in the past, plus a shorter recent run.
        let entries = [10, 11, 12, 13, 14].map { entry(daysAgo: $0) } + [entry(daysAgo: 0)]
        let s = DiaryStatistics.compute(from: entries, calendar: cal, today: today())
        XCTAssertEqual(s.longestStreak, 5)
    }

    func testMoodDistributionSortedByCount() {
        let s = DiaryStatistics.compute(from: [
            entry(daysAgo: 0, mood: "😊"), entry(daysAgo: 1, mood: "😊"),
            entry(daysAgo: 2, mood: "😢"), entry(daysAgo: 3, mood: "😊"),
        ], calendar: cal, today: today())
        XCTAssertEqual(s.moods.first?.emoji, "😊")
        XCTAssertEqual(s.moods.first?.count, 3)
        XCTAssertEqual(s.moods.last?.emoji, "😢")
    }

    func testEntriesThisMonthAndMedia() {
        let s = DiaryStatistics.compute(from: [
            entry(daysAgo: 0, images: ["a.jpg"]),         // this month, has photo
            entry(daysAgo: 1, audio: "a.m4a"),            // this month, has audio
            entry(daysAgo: 40),                            // previous month
        ], calendar: cal, today: today())
        XCTAssertEqual(s.entriesThisMonth, 2)
        XCTAssertEqual(s.withPhotos, 1)
        XCTAssertEqual(s.withAudio, 1)
    }

    func testMonthlyBucketsAreChronological() {
        // today = 2026-07-15; -40d ≈ Jun 5; -75d ≈ May 1.
        let s = DiaryStatistics.compute(from: [
            entry(daysAgo: 0), entry(daysAgo: 40), entry(daysAgo: 75),
        ], calendar: cal, today: today())
        XCTAssertEqual(s.months.map(\.key), ["2026年5月", "2026年6月", "2026年7月"])
        XCTAssertEqual(s.months.map(\.count), [1, 1, 1])
    }
}
