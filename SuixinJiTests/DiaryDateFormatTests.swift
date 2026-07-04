import XCTest
@testable import SuixinJi

/// Date / duration formatting. Dates are built at local noon so the day never
/// slips across a timezone boundary; the formatters force `zh_CN` output.
final class DiaryDateFormatTests: XCTestCase {

    /// 2026-07-04 (a Saturday) at 12:00 local.
    private func july4() -> Date {
        var c = DateComponents()
        c.year = 2026; c.month = 7; c.day = 4; c.hour = 12
        return Calendar(identifier: .gregorian).date(from: c)!
    }

    func testLongChinese() {
        XCTAssertEqual(DiaryDateFormat.longChinese(july4()), "7月4日 星期六")
    }

    func testShortChinese() {
        XCTAssertEqual(DiaryDateFormat.shortChinese(july4()), "7月4日")
    }

    func testDayNumber() {
        XCTAssertEqual(DiaryDateFormat.dayNumber(july4()), "4日")
    }

    func testWeekdayShort() {
        XCTAssertEqual(DiaryDateFormat.weekdayShort(july4()), "周六")
    }

    func testYearMonth() {
        XCTAssertEqual(DiaryDateFormat.yearMonth(july4()), "2026年7月")
    }

    func testDurationUnpadded() {
        XCTAssertEqual(DiaryDateFormat.duration(35), "0:35")
        XCTAssertEqual(DiaryDateFormat.duration(95), "1:35")
        XCTAssertEqual(DiaryDateFormat.duration(0), "0:00")
    }

    func testDurationPadded() {
        XCTAssertEqual(DiaryDateFormat.duration(35, padMinutes: true), "00:35")
        XCTAssertEqual(DiaryDateFormat.duration(600, padMinutes: true), "10:00")
    }

    func testDurationRounding() {
        XCTAssertEqual(DiaryDateFormat.duration(34.6), "0:35")
        XCTAssertEqual(DiaryDateFormat.duration(34.4), "0:34")
    }
}
