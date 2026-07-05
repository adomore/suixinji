import Foundation

/// A shareable summary of one month (evolution). Rendered by `RecapCard` and
/// exportable as a long image. Pure/deterministic for unit testing.
struct MonthlyRecap: Equatable {
    let monthKey: String       // "2026年7月"
    let entryCount: Int
    let daysWritten: Int
    let topMood: String?
    let withPhotos: Int
    let withAudio: Int

    var isEmpty: Bool { entryCount == 0 }

    static func build(
        from entries: [DiaryEntry],
        month: Date,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> MonthlyRecap {
        let comps = calendar.dateComponents([.year, .month], from: month)
        let monthEntries = entries.filter {
            let c = calendar.dateComponents([.year, .month], from: $0.diaryDate)
            return c.year == comps.year && c.month == comps.month
        }
        let days = Set(monthEntries.map { calendar.startOfDay(for: $0.diaryDate) })

        var moodMap: [String: Int] = [:]
        for e in monthEntries where !(e.mood ?? "").isEmpty { moodMap[e.mood!, default: 0] += 1 }
        let topMood = moodMap
            .sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
            .first?.key

        return MonthlyRecap(
            monthKey: "\(comps.year!)年\(comps.month!)月",
            entryCount: monthEntries.count,
            daysWritten: days.count,
            topMood: topMood,
            withPhotos: monthEntries.filter { !$0.imageFileNames.isEmpty }.count,
            withAudio: monthEntries.filter { $0.audioFileName != nil }.count
        )
    }
}
