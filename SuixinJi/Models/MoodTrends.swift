import Foundation

/// 情绪趋势 (evolution). Maps the catalog moods (`DiaryCatalog.moods`) to a valence
/// score and averages them per month, so 统计 can chart how mood moves over time.
/// Pure & testable — the Swift Charts view just plots what this returns.
enum MoodTrends {
    /// Valence for each catalog mood; higher = brighter. 😴 (sleepy) is treated as
    /// emotionally neutral. Only these moods count toward the trend.
    static let valence: [String: Double] = [
        "😊": 2, "🥳": 2, "🙂": 1, "😐": 0, "😴": 0, "😔": -1, "😢": -2, "😡": -2
    ]

    /// Chart y-range.
    static let domain: ClosedRange<Double> = -2...2

    struct MonthPoint: Identifiable, Equatable {
        let id: String        // "yyyy-MM"
        let month: Date       // first day of the month
        let average: Double   // mean valence of that month's mood-tagged entries
        let count: Int        // number of mood-tagged entries that month
    }

    /// Average mood valence for each month in the last `months` window (oldest
    /// first), ending with the month containing `today`. Only entries whose mood is
    /// in the catalog count; a month with none is **omitted** (a gap reads truer
    /// than a fake neutral 0).
    static func monthlyValence(_ entries: [DiaryEntry], today: Date = Date(),
                               months: Int = 6, calendar: Calendar = .current) -> [MonthPoint] {
        guard months > 0,
              let thisMonth = monthStart(of: today, calendar: calendar),
              let windowStart = calendar.date(byAdding: .month, value: -(months - 1), to: thisMonth)
        else { return [] }

        var buckets: [String: (sum: Double, count: Int, month: Date)] = [:]
        for e in entries {
            guard let mood = e.mood, let v = valence[mood],
                  let m = monthStart(of: e.diaryDate, calendar: calendar),
                  m >= windowStart, m <= thisMonth else { continue }
            let k = key(m, calendar: calendar)
            let cur = buckets[k] ?? (0, 0, m)
            buckets[k] = (cur.sum + v, cur.count + 1, m)
        }
        return buckets.values
            .map { MonthPoint(id: key($0.month, calendar: calendar), month: $0.month,
                              average: $0.sum / Double($0.count), count: $0.count) }
            .sorted { $0.month < $1.month }
    }

    /// A representative face for an integer valence tick — the chart's y-axis labels.
    static func face(forValence v: Int) -> String {
        switch v {
        case 2...: return "😊"
        case 1: return "🙂"
        case 0: return "😐"
        case -1: return "😔"
        default: return "😢"
        }
    }

    static func key(_ month: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month], from: month)
        return String(format: "%04d-%02d", c.year ?? 0, c.month ?? 0)
    }

    private static func monthStart(of date: Date, calendar: Calendar) -> Date? {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date))
    }
}
