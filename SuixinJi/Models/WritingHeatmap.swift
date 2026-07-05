import Foundation

/// 写作热力图 (evolution). GitHub-contribution-style grid of daily writing activity.
/// Pure & deterministic (`today` + `calendar` injectable) so the view just plots
/// what this returns.
enum WritingHeatmap {
    /// One day cell in the grid.
    struct Cell: Equatable, Identifiable {
        let date: Date       // start-of-day
        let count: Int       // entries written that day
        let isFuture: Bool   // trailing days of the current week (after today)
        var id: Date { date }
        /// Colour bucket 0…4 (0 = none, 4 = most active).
        var level: Int { WritingHeatmap.level(count) }
    }

    /// Weeks shown ≈ one year.
    static let weeksShown = 53

    /// Colour bucket for a day's entry count.
    static func level(_ count: Int) -> Int {
        switch count {
        case ..<1: return 0
        case 1:    return 1
        case 2:    return 2
        case 3:    return 3
        default:   return 4
        }
    }

    /// Entry count per calendar day (keyed by start-of-day).
    static func counts(_ entries: [DiaryEntry], calendar: Calendar = .current) -> [Date: Int] {
        var map: [Date: Int] = [:]
        for e in entries {
            map[calendar.startOfDay(for: e.diaryDate), default: 0] += 1
        }
        return map
    }

    /// Columns of the heatmap: each inner array is one week of 7 `Cell`s (first
    /// weekday → last, per `calendar.firstWeekday`), oldest week first, ending with
    /// the week that contains `today`.
    static func columns(from entries: [DiaryEntry], today: Date = Date(),
                        weeks: Int = weeksShown, calendar: Calendar = .current) -> [[Cell]] {
        guard weeks > 0 else { return [] }
        let byDay = counts(entries, calendar: calendar)
        let todayStart = calendar.startOfDay(for: today)
        guard let thisWeekStart = weekStart(of: todayStart, calendar: calendar),
              let gridStart = calendar.date(byAdding: .weekOfYear, value: -(weeks - 1), to: thisWeekStart)
        else { return [] }

        var result: [[Cell]] = []
        result.reserveCapacity(weeks)
        for w in 0..<weeks {
            guard let colStart = calendar.date(byAdding: .weekOfYear, value: w, to: gridStart) else { continue }
            var column: [Cell] = []
            column.reserveCapacity(7)
            for d in 0..<7 {
                guard let day = calendar.date(byAdding: .day, value: d, to: colStart) else { continue }
                column.append(Cell(date: day,
                                   count: byDay[day] ?? 0,
                                   isFuture: day > todayStart))
            }
            result.append(column)
        }
        return result
    }

    /// Number of real (non-future) days with at least one entry in the grid — for a caption.
    static func writtenDays(in columns: [[Cell]]) -> Int {
        columns.reduce(0) { acc, week in
            acc + week.filter { !$0.isFuture && $0.count > 0 }.count
        }
    }

    /// First day of the calendar week containing `date` (respects `firstWeekday`).
    private static func weekStart(of date: Date, calendar: Calendar) -> Date? {
        calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date))
    }
}
