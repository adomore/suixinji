import XCTest
@testable import SuixinJi

/// 情绪趋势 engine (evolution). Pure monthly valence averaging.
final class MoodTrendsTests: XCTestCase {
    private let cal = Calendar(identifier: .gregorian)

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d))!
    }
    private func entry(_ mood: String?, _ date: Date) -> DiaryEntry {
        DiaryEntry(diaryDate: date, text: "x", mood: mood)
    }

    func testAveragesValencePerMonth() throws {
        let today = date(2026, 7, 20)
        let e = [entry("😊", date(2026, 7, 3)),  // +2
                 entry("😐", date(2026, 7, 10))] // 0
        let pts = MoodTrends.monthlyValence(e, today: today, calendar: cal)
        XCTAssertEqual(pts.count, 1)
        let p = try XCTUnwrap(pts.first)
        XCTAssertEqual(p.average, 1.0, accuracy: 1e-9) // (2+0)/2
        XCTAssertEqual(p.count, 2)
        XCTAssertEqual(p.id, "2026-07")
    }

    func testSeparatesMonthsOldestFirst() throws {
        let today = date(2026, 7, 20)
        let e = [entry("😢", date(2026, 6, 5)),   // -2, June
                 entry("😊", date(2026, 7, 5))]    // +2, July
        let pts = MoodTrends.monthlyValence(e, today: today, calendar: cal)
        XCTAssertEqual(pts.map(\.id), ["2026-06", "2026-07"])
        XCTAssertEqual(try XCTUnwrap(pts.first).average, -2.0, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(pts.last).average, 2.0, accuracy: 1e-9)
    }

    func testIgnoresNilAndUnknownMoods() throws {
        let today = date(2026, 7, 20)
        let e = [entry(nil, date(2026, 7, 5)),
                 entry("🤯", date(2026, 7, 6)),  // not in catalog
                 entry("🙂", date(2026, 7, 7))]  // +1
        let pts = MoodTrends.monthlyValence(e, today: today, calendar: cal)
        XCTAssertEqual(pts.count, 1)
        let p = try XCTUnwrap(pts.first)
        XCTAssertEqual(p.count, 1)
        XCTAssertEqual(p.average, 1.0, accuracy: 1e-9)
    }

    func testWindowExcludesMonthsBeforeWindowStart() {
        let today = date(2026, 7, 20) // 6-month window = 2026-02 … 2026-07
        let e = [entry("😊", date(2026, 1, 15)),  // Jan — outside
                 entry("😊", date(2026, 2, 1)),   // Feb — inside (window start)
                 entry("😊", date(2026, 7, 1))]    // Jul — inside
        let pts = MoodTrends.monthlyValence(e, today: today, months: 6, calendar: cal)
        XCTAssertEqual(pts.map(\.id), ["2026-02", "2026-07"])
    }

    func testFutureMonthsExcluded() {
        let today = date(2026, 7, 20)
        let e = [entry("😊", date(2026, 8, 1))] // next month — excluded
        XCTAssertTrue(MoodTrends.monthlyValence(e, today: today, calendar: cal).isEmpty)
    }

    func testEmptyWhenNoMoods() {
        XCTAssertTrue(MoodTrends.monthlyValence([], today: date(2026, 7, 20), calendar: cal).isEmpty)
    }

    func testFaceForValence() {
        XCTAssertEqual(MoodTrends.face(forValence: 2), "😊")
        XCTAssertEqual(MoodTrends.face(forValence: 0), "😐")
        XCTAssertEqual(MoodTrends.face(forValence: -2), "😢")
    }
}
