import Foundation

/// "回顾 · 记忆" logic (evolution): On-This-Day lookups and streak milestones.
/// Pure and deterministic (`today` + `calendar` injectable) for unit testing.
enum Memories {
    /// Streak milestones celebrated in the UI.
    static let milestones = [7, 30, 100, 365]

    /// Entries from earlier years that share today's month & day ("去年今天 /
    /// 这一天"), newest first.
    static func onThisDay(_ entries: [DiaryEntry], today: Date, calendar: Calendar) -> [DiaryEntry] {
        let t = calendar.dateComponents([.year, .month, .day], from: today)
        return entries.filter {
            let c = calendar.dateComponents([.year, .month, .day], from: $0.diaryDate)
            return c.month == t.month && c.day == t.day && (c.year ?? 0) < (t.year ?? 0)
        }.sorted { $0.diaryDate > $1.diaryDate }
    }

    /// Whole years between `date` and `today` (≥ 1).
    static func yearsAgo(_ date: Date, from today: Date, calendar: Calendar) -> Int {
        max(1, calendar.dateComponents([.year], from: date, to: today).year ?? 1)
    }

    /// The next milestone strictly above the current streak (nil once past 365).
    static func nextMilestone(currentStreak: Int) -> Int? {
        milestones.first { $0 > currentStreak }
    }

    /// Milestones already reached by the longest streak.
    static func achievedMilestones(longestStreak: Int) -> [Int] {
        milestones.filter { $0 <= longestStreak }
    }
}
