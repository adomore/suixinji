import Foundation

/// 传统节日 (evolution). Names the festival a date falls on — lunar (春节/端午/中秋…,
/// derived from the `.chinese` calendar) or fixed-solar (元旦/国庆…). Pure & testable;
/// pairs with `LunarDate`. Returns nil for ordinary days.
enum Festival {
    /// "lunarMonth-lunarDay" → name (non-leap months only).
    private static let lunar: [String: String] = [
        "1-1": "春节", "1-15": "元宵", "5-5": "端午", "7-7": "七夕",
        "8-15": "中秋", "9-9": "重阳", "12-8": "腊八"
    ]
    /// "gregMonth-gregDay" → name.
    private static let solar: [String: String] = [
        "1-1": "元旦", "5-1": "劳动节", "6-1": "儿童节", "10-1": "国庆", "12-25": "圣诞"
    ]

    /// All festival names (for localization enumeration / tests).
    static var allNames: [String] { Array(lunar.values) + Array(solar.values) + ["除夕"] }

    /// The festival name for `date`, or nil. Lunar festivals win over solar on the
    /// (essentially impossible) collision; 除夕 is detected as the day before 春节.
    static func name(for date: Date,
                     gregorian: Calendar = Calendar(identifier: .gregorian),
                     chinese: Calendar = Calendar(identifier: .chinese)) -> String? {
        let c = chinese.dateComponents([.month, .day], from: date)
        let isLeap = c.isLeapMonth ?? false
        if !isLeap, let m = c.month, let d = c.day, let f = lunar["\(m)-\(d)"] {
            return f
        }
        // 除夕 — the day whose next day is 正月初一.
        if let next = gregorian.date(byAdding: .day, value: 1, to: date) {
            let nc = chinese.dateComponents([.month, .day], from: next)
            if nc.month == 1, nc.day == 1, !(nc.isLeapMonth ?? false) { return "除夕" }
        }
        let g = gregorian.dateComponents([.month, .day], from: date)
        if let m = g.month, let d = g.day, let f = solar["\(m)-\(d)"] {
            return f
        }
        return nil
    }
}
