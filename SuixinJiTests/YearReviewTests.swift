import XCTest
@testable import SuixinJi

/// 年度报告 engine (evolution). Pure annual aggregation.
final class YearReviewTests: XCTestCase {
    private let cal = Calendar(identifier: .gregorian)

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d))!
    }
    private func entry(_ date: Date, mood: String? = nil, tags: [String] = [],
                       place: String? = nil, images: [String] = [], audio: String? = nil) -> DiaryEntry {
        DiaryEntry(diaryDate: date, text: "x", mood: mood, tags: tags,
                   locationName: place, imageFileNames: images, audioFileName: audio)
    }

    func testCountsEntriesAndDaysForYearOnly() {
        let e = [entry(date(2026, 7, 1)), entry(date(2026, 7, 1)), // same day
                 entry(date(2026, 3, 2)),
                 entry(date(2025, 12, 31))]                        // different year — excluded
        let r = YearReview.build(from: e, year: 2026, calendar: cal)
        XCTAssertEqual(r.entryCount, 3)
        XCTAssertEqual(r.daysWritten, 2)
        XCTAssertFalse(r.isEmpty)
    }

    func testTopMonth() {
        let e = [entry(date(2026, 7, 1)), entry(date(2026, 7, 9)), entry(date(2026, 7, 20)),
                 entry(date(2026, 4, 1))]
        let r = YearReview.build(from: e, year: 2026, calendar: cal)
        XCTAssertEqual(r.topMonth, "7月")
        XCTAssertEqual(r.topMonthCount, 3)
    }

    func testTopMoodAndTags() {
        let e = [entry(date(2026, 1, 1), mood: "😊", tags: ["旅行", "美食"]),
                 entry(date(2026, 1, 2), mood: "😊", tags: ["旅行"]),
                 entry(date(2026, 1, 3), mood: "😢", tags: ["工作"])]
        let r = YearReview.build(from: e, year: 2026, calendar: cal)
        XCTAssertEqual(r.topMood, "😊")
        XCTAssertEqual(r.topTags.first, YearReview.TagCount(tag: "旅行", count: 2))
        XCTAssertLessThanOrEqual(r.topTags.count, 3)
    }

    func testMediaAndPlaces() {
        let e = [entry(date(2026, 5, 1), place: "杭州", images: ["a.jpg"]),
                 entry(date(2026, 5, 2), place: "杭州", audio: "b.m4a"),   // same place
                 entry(date(2026, 5, 3), place: "上海")]
        let r = YearReview.build(from: e, year: 2026, calendar: cal)
        XCTAssertEqual(r.withPhotos, 1)
        XCTAssertEqual(r.withAudio, 1)
        XCTAssertEqual(r.placesCount, 2) // 杭州 + 上海, deduped
    }

    func testLongestRunWithinYear() {
        let e = [entry(date(2026, 7, 1)), entry(date(2026, 7, 2)), entry(date(2026, 7, 3)), // run of 3
                 entry(date(2026, 7, 10))]                                                   // isolated
        let r = YearReview.build(from: e, year: 2026, calendar: cal)
        XCTAssertEqual(r.longestStreak, 3)
    }

    func testEmptyYear() {
        let r = YearReview.build(from: [entry(date(2025, 1, 1))], year: 2026, calendar: cal)
        XCTAssertTrue(r.isEmpty)
        XCTAssertEqual(r.entryCount, 0)
        XCTAssertNil(r.topMonth)
        XCTAssertEqual(r.longestStreak, 0)
    }
}
