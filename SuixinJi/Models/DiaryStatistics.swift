import Foundation

/// Aggregate insights over the diary (an evolution beyond the PRD's F1–F14):
/// writing streaks, monthly activity, mood distribution, and media counts.
/// Pure and deterministic (`today` + `calendar` are injectable) so the streak
/// math can be unit-tested precisely.
struct DiaryStatistics: Equatable {
    var totalEntries = 0
    var daysWritten = 0          // distinct calendar days with an entry
    var currentStreak = 0        // consecutive days up to today (1-day grace)
    var longestStreak = 0
    var entriesThisMonth = 0
    var withPhotos = 0
    var withAudio = 0
    var moods: [MoodStat] = []    // sorted by count desc
    var months: [MonthStat] = []  // last ≤6 active months, chronological

    struct MoodStat: Identifiable, Equatable {
        let emoji: String
        let count: Int
        var id: String { emoji }
    }
    struct MonthStat: Identifiable, Equatable {
        let key: String            // "2026年7月"
        let count: Int
        var id: String { key }
    }

    static func compute(
        from entries: [DiaryEntry],
        calendar: Calendar = Calendar(identifier: .gregorian),
        today: Date = Date()
    ) -> DiaryStatistics {
        var stats = DiaryStatistics()
        stats.totalEntries = entries.count
        guard !entries.isEmpty else { return stats }

        let days = Set(entries.map { calendar.startOfDay(for: $0.diaryDate) })
        stats.daysWritten = days.count
        stats.currentStreak = currentStreak(days: days, today: today, calendar: calendar)
        stats.longestStreak = longestStreak(days: days, calendar: calendar)

        let now = calendar.dateComponents([.year, .month], from: today)
        stats.entriesThisMonth = entries.filter {
            let c = calendar.dateComponents([.year, .month], from: $0.diaryDate)
            return c.year == now.year && c.month == now.month
        }.count

        stats.withPhotos = entries.filter { !$0.imageFileNames.isEmpty }.count
        stats.withAudio = entries.filter { $0.audioFileName != nil }.count

        var moodMap: [String: Int] = [:]
        for e in entries where !(e.mood ?? "").isEmpty { moodMap[e.mood!, default: 0] += 1 }
        stats.moods = moodMap
            .map { MoodStat(emoji: $0.key, count: $0.value) }
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0.emoji < $1.emoji }

        var monthMap: [DateComponents: Int] = [:]
        for e in entries {
            let c = calendar.dateComponents([.year, .month], from: e.diaryDate)
            monthMap[c, default: 0] += 1
        }
        let sortedKeys = monthMap.keys.sorted { ($0.year!, $0.month!) < ($1.year!, $1.month!) }
        stats.months = sortedKeys.suffix(6).map { c in
            MonthStat(key: "\(c.year!)年\(c.month!)月", count: monthMap[c]!)
        }
        return stats
    }

    // MARK: Streaks

    /// Consecutive days ending at today. If today has no entry the streak may
    /// still be "alive" from yesterday (a one-day grace, habit-tracker style).
    static func currentStreak(days: Set<Date>, today: Date, calendar: Calendar) -> Int {
        var cursor = calendar.startOfDay(for: today)
        if !days.contains(cursor) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor),
                  days.contains(yesterday) else { return 0 }
            cursor = yesterday
        }
        var streak = 0
        while days.contains(cursor) {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return streak
    }

    /// Longest run of consecutive calendar days anywhere in the history.
    static func longestStreak(days: Set<Date>, calendar: Calendar) -> Int {
        let sorted = days.sorted()
        var longest = 0, run = 0
        var prev: Date?
        for day in sorted {
            if let p = prev,
               let next = calendar.date(byAdding: .day, value: 1, to: p),
               calendar.isDate(next, inSameDayAs: day) {
                run += 1
            } else {
                run = 1
            }
            longest = max(longest, run)
            prev = day
        }
        return longest
    }
}
