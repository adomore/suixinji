import Foundation

/// 年度报告 · Year in Review (evolution). A shareable annual summary, rendered by
/// `YearReviewCard` and exported as a long image (`DiaryExporter.exportYearReview`).
/// Pure/deterministic for unit testing.
struct YearReview: Equatable {
    let year: Int
    let entryCount: Int
    let daysWritten: Int
    let longestStreak: Int         // longest consecutive-day run within the year
    let topMonth: String?          // e.g. "7月" — the month with the most entries
    let topMonthCount: Int
    let topMood: String?
    let topTags: [TagCount]        // up to 3, count desc
    let withPhotos: Int
    let withAudio: Int
    let placesCount: Int           // distinct non-empty locationName

    struct TagCount: Equatable { let tag: String; let count: Int }

    var isEmpty: Bool { entryCount == 0 }

    static func build(from entries: [DiaryEntry], year: Int,
                      calendar: Calendar = Calendar(identifier: .gregorian)) -> YearReview {
        let yearEntries = entries.filter { calendar.component(.year, from: $0.diaryDate) == year }

        let days = Set(yearEntries.map { calendar.startOfDay(for: $0.diaryDate) })

        // Most active month.
        var monthCounts: [Int: Int] = [:]
        for e in yearEntries { monthCounts[calendar.component(.month, from: e.diaryDate), default: 0] += 1 }
        let top = monthCounts.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }.first

        // Top mood.
        var moodMap: [String: Int] = [:]
        for e in yearEntries where !(e.mood ?? "").isEmpty { moodMap[e.mood!, default: 0] += 1 }
        let topMood = moodMap.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }.first?.key

        // Top tags.
        var tagMap: [String: Int] = [:]
        for e in yearEntries { for t in e.tags where !t.isEmpty { tagMap[t, default: 0] += 1 } }
        let topTags = tagMap
            .sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
            .prefix(3)
            .map { TagCount(tag: $0.key, count: $0.value) }

        let places = Set(yearEntries.compactMap { e -> String? in
            let name = e.locationName ?? ""
            return name.isEmpty ? nil : name
        })

        return YearReview(
            year: year,
            entryCount: yearEntries.count,
            daysWritten: days.count,
            longestStreak: longestRun(days, calendar: calendar),
            topMonth: top.map { "\($0.key)月" },
            topMonthCount: top?.value ?? 0,
            topMood: topMood,
            topTags: Array(topTags),
            withPhotos: yearEntries.filter { !$0.imageFileNames.isEmpty }.count,
            withAudio: yearEntries.filter { $0.audioFileName != nil }.count,
            placesCount: places.count
        )
    }

    /// Longest run of consecutive calendar days in the set.
    static func longestRun(_ days: Set<Date>, calendar: Calendar) -> Int {
        var longest = 0
        for day in days {
            // Only start counting from a run's first day.
            guard let prev = calendar.date(byAdding: .day, value: -1, to: day), !days.contains(prev) else { continue }
            var len = 1
            var cursor = day
            while let next = calendar.date(byAdding: .day, value: 1, to: cursor), days.contains(next) {
                len += 1; cursor = next
            }
            longest = max(longest, len)
        }
        return longest
    }
}
