import Foundation

/// 农历日期 (evolution). Formats a date as a traditional Chinese lunar label like
/// "腊月廿三" or "闰二月初一", using Foundation's `.chinese` calendar for the
/// conversion and a pure numeral mapping for the names. Pure & unit-testable.
enum LunarDate {
    // 1…12 → 正/二/…/十/冬/腊 (index 0 unused).
    private static let monthChars = ["", "正", "二", "三", "四", "五", "六", "七", "八", "九", "十", "冬", "腊"]
    // 1…10 → 一…十 (index 0 unused).
    private static let digits = ["", "一", "二", "三", "四", "五", "六", "七", "八", "九", "十"]

    /// e.g. 1 → "正月", 11 → "冬月", 12 → "腊月"; leap months prefix "闰".
    static func monthName(_ month: Int, isLeap: Bool = false) -> String {
        guard month >= 1, month <= 12 else { return "" }
        return (isLeap ? "闰" : "") + monthChars[month] + "月"
    }

    /// e.g. 1 → "初一", 10 → "初十", 23 → "廿三", 30 → "三十".
    static func dayName(_ day: Int) -> String {
        switch day {
        case 10: return "初十"
        case 20: return "二十"
        case 30: return "三十"
        case 1...9: return "初" + digits[day]
        case 11...19: return "十" + digits[day - 10]
        case 21...29: return "廿" + digits[day - 20]
        default: return ""
        }
    }

    /// The lunar label for a Gregorian date (e.g. "正月初一"). Empty on failure.
    static func format(_ date: Date, calendar: Calendar = Calendar(identifier: .chinese)) -> String {
        let c = calendar.dateComponents([.month, .day], from: date)
        guard let m = c.month, let d = c.day else { return "" }
        return monthName(m, isLeap: c.isLeapMonth ?? false) + dayName(d)
    }
}
