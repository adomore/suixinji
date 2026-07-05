import Foundation

/// 每日灵感 (evolution). A curated rotation of gentle writing prompts, plus a
/// deterministic "prompt of the day" so the home banner is stable across a day
/// and only changes at midnight. Pure & testable.
enum WritingPrompts {
    /// Calm, everyday prompts (Brief tone — no pressure, no gamification-speak).
    static let all: [String] = [
        "今天，有什么让你嘴角上扬的小事？",
        "此刻你在想什么？把它写下来。",
        "今天遇到的一个人，让你有什么感受？",
        "如果用一个词形容今天，会是什么？为什么？",
        "最近有什么一直放不下的事？",
        "今天你对自己说的一句话是？",
        "有什么想感谢的人或事吗？",
        "今天吃到、看到、听到的，哪一样最难忘？",
        "如果可以对昨天的自己说一句话，你会说什么？",
        "此刻窗外是什么样子？你的心情呢？",
        "最近让你悄悄期待的一件事是什么？",
        "今天有没有一个瞬间，你希望它慢一点？",
        "写下一件今天做成的小事，哪怕很小。",
        "此刻身体累吗？心累吗？发生了什么？",
        "如果今天是一部电影，它的名字叫？"
    ]

    /// The prompt for a given day — stable within the day, rotates daily.
    static func ofTheDay(_ date: Date = Date(), calendar: Calendar = .current) -> String {
        let day = calendar.ordinality(of: .day, in: .era, for: date) ?? 0
        let index = ((day % all.count) + all.count) % all.count // safe modulo
        return all[index]
    }
}

/// 写作习惯 (evolution). Which of the last N days have at least one entry — drives
/// a small week strip. Pure & testable; streak itself lives in `DiaryStatistics`.
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
