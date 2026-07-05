import Foundation

/// 写作习惯 (evolution). Which of the last N days have at least one entry — drives
/// a small week strip. Pure & testable; streak itself lives in `DiaryStatistics`.
/// (The pure `WritingPrompts` daily-line logic lives in Shared/ so the widget can
/// reuse it.)
enum WritingHabit {
    struct Day: Equatable {
        let date: Date
        let written: Bool
    }

    /// The last `count` days ending on `today` (oldest first), each flagged with
    /// whether any entry's `diaryDate` falls on it.
    static func recentDays(_ entries: [DiaryEntry], today: Date = Date(),
                           count: Int = 7, calendar: Calendar = .current) -> [Day] {
        let writtenDays = Set(entries.map { calendar.startOfDay(for: $0.diaryDate) })
        let start = calendar.startOfDay(for: today)
        return (0..<count).reversed().map { offset in
            let day = calendar.date(byAdding: .day, value: -offset, to: start) ?? start
            return Day(date: day, written: writtenDays.contains(day))
        }
    }
}
