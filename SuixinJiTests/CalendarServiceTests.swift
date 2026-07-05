import XCTest
@testable import SuixinJi

/// 日历联动 (evolution). The event→text formatting is pure (no EventKit), so we can
/// verify the diary block it produces.
final class CalendarServiceTests: XCTestCase {

    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return c
    }()
    private let locale = Locale(identifier: "zh_CN")

    private func date(_ h: Int, _ m: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 7, day: 5, hour: h, minute: m))!
    }

    func testEmptyEventsGivesEmptyString() {
        XCTAssertEqual(CalendarService.summary(for: [], locale: locale, calendar: calendar), "")
    }

    func testFormatsTimedEvents() {
        let items = [
            CalendarService.EventItem(title: "晨会", start: date(9, 0), isAllDay: false),
            CalendarService.EventItem(title: "午餐", start: date(12, 30), isAllDay: false)
        ]
        let out = CalendarService.summary(for: items, locale: locale, calendar: calendar)
        XCTAssertEqual(out, "今天的日程：\n· 09:00 晨会\n· 12:30 午餐")
    }

    func testAllDayEventShowsAllDayLabel() {
        let items = [CalendarService.EventItem(title: "出差", start: date(0, 0), isAllDay: true)]
        let out = CalendarService.summary(for: items, locale: locale, calendar: calendar)
        XCTAssertEqual(out, "今天的日程：\n· 全天 出差")
    }

    func testUntitledEventGetsPlaceholder() {
        let items = [CalendarService.EventItem(title: "   ", start: date(8, 0), isAllDay: false)]
        let out = CalendarService.summary(for: items, locale: locale, calendar: calendar)
        XCTAssertEqual(out, "今天的日程：\n· 08:00 （无标题）")
    }

    func testDayBoundsSpanExactlyOneDay() throws {
        let bounds = try XCTUnwrap(CalendarService.dayBounds(date(15, 0), calendar: calendar))
        XCTAssertEqual(bounds.start, calendar.startOfDay(for: date(15, 0)))
        XCTAssertEqual(calendar.dateComponents([.day], from: bounds.start, to: bounds.end).day, 1)
    }
}
