import Foundation

/// 每日灵感 (evolution). A curated rotation of gentle writing prompts, plus a
/// deterministic "prompt of the day" so the home banner — and the 今日一句 widget —
/// stay stable across a day and only change at midnight. Pure & testable.
/// Lives in Shared/ so the app and the widget compute the identical daily line.
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
