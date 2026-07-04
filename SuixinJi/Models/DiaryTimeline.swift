import Foundation

/// Groups already-sorted entries into contiguous year-month sections for the
/// timeline (PRD §F5). Pure and view-free so it can be unit-tested directly.
enum DiaryTimeline {
    struct Section: Identifiable, Equatable {
        let key: String            // "2026年7月" (from diaryDate)
        let entries: [DiaryEntry]
        /// Unique per contiguous run — a back-dated entry can produce two runs
        /// with the same `key`, so the id also folds in the run's first entry to
        /// keep ForEach IDs distinct.
        var id: String { "\(key)#\(entries.first?.id.uuidString ?? "")" }

        static func == (lhs: Section, rhs: Section) -> Bool {
            lhs.key == rhs.key && lhs.entries.map(\.id) == rhs.entries.map(\.id)
        }
    }

    /// Split `entries` (assumed already in display order — newest `createdAt`
    /// first) into contiguous runs sharing a diaryDate year-month.
    static func sections(from entries: [DiaryEntry]) -> [Section] {
        var result: [Section] = []
        var currentKey: String?
        var bucket: [DiaryEntry] = []
        for entry in entries {
            let key = DiaryDateFormat.yearMonth(entry.diaryDate)
            if key != currentKey {
                if let currentKey { result.append(Section(key: currentKey, entries: bucket)) }
                currentKey = key
                bucket = [entry]
            } else {
                bucket.append(entry)
            }
        }
        if let currentKey { result.append(Section(key: currentKey, entries: bucket)) }
        return result
    }
}
