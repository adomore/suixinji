import XCTest
@testable import SuixinJi

/// 农历日期 (evolution). The numeral mapping is pure and exhaustively checkable;
/// `format` is anchored on a well-known Chinese New Year date.
final class LunarDateTests: XCTestCase {

    func testMonthNames() {
        XCTAssertEqual(LunarDate.monthName(1), "正月")
        XCTAssertEqual(LunarDate.monthName(6), "六月")
        XCTAssertEqual(LunarDate.monthName(11), "冬月")
        XCTAssertEqual(LunarDate.monthName(12), "腊月")
        XCTAssertEqual(LunarDate.monthName(2, isLeap: true), "闰二月")
        XCTAssertEqual(LunarDate.monthName(0), "")   // out of range
        XCTAssertEqual(LunarDate.monthName(13), "")
    }

    func testDayNames() {
        XCTAssertEqual(LunarDate.dayName(1), "初一")
        XCTAssertEqual(LunarDate.dayName(9), "初九")
        XCTAssertEqual(LunarDate.dayName(10), "初十")
        XCTAssertEqual(LunarDate.dayName(11), "十一")
        XCTAssertEqual(LunarDate.dayName(19), "十九")
        XCTAssertEqual(LunarDate.dayName(20), "二十")
        XCTAssertEqual(LunarDate.dayName(23), "廿三")
        XCTAssertEqual(LunarDate.dayName(29), "廿九")
        XCTAssertEqual(LunarDate.dayName(30), "三十")
    }

    /// A `.chinese` calendar pinned to China time so the day bucketing is stable
    /// regardless of the host's timezone (the app itself uses the device timezone).
    private let chinaLunar: Calendar = {
        var c = Calendar(identifier: .chinese)
        c.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return c
    }()

    func testFormatOnChineseNewYear2025() {
        // 2025 春节 = 2025-01-29 (Gregorian) → 农历 正月初一.
        var g = Calendar(identifier: .gregorian)
        g.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        let cny = g.date(from: DateComponents(year: 2025, month: 1, day: 29, hour: 12))!
        XCTAssertEqual(LunarDate.format(cny, calendar: chinaLunar), "正月初一")
    }

    func testFormatIsNonEmptyAndWellFormed() {
        var g = Calendar(identifier: .gregorian)
        g.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        let d = g.date(from: DateComponents(year: 2026, month: 7, day: 5, hour: 12))!
        let s = LunarDate.format(d, calendar: chinaLunar)
        XCTAssertTrue(s.contains("月"), "should contain a lunar month: \(s)")
        XCTAssertFalse(s.isEmpty)
    }
}
