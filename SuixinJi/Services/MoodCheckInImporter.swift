import Foundation
import SwiftData

/// Drains the 快速心情打卡 widget's `MoodInbox` into diary entries (evolution).
/// Runs when the app becomes active. A check-in updates today's existing *check-in*
/// card if there is one (so repeated taps just change the mood), otherwise inserts a
/// new minimal mood entry. A real written entry is never overwritten.
enum MoodCheckInImporter {
    /// A today entry that is itself a bare check-in — empty text, no photos, no audio —
    /// and can therefore be updated in place instead of spawning another near-empty
    /// card. Returns nil when today has no such entry. Pure & testable.
    static func updatableCheckIn(in entries: [DiaryEntry], on day: Date,
                                 calendar: Calendar = .current) -> DiaryEntry? {
        entries.first { e in
            calendar.isDate(e.diaryDate, inSameDayAs: day)
                && e.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && e.imageFileNames.isEmpty
                && e.audioFileName == nil
        }
    }

    @discardableResult
    @MainActor
    static func importPending(into context: ModelContext) -> Int {
        let pending = MoodInbox.pending()
        guard !pending.isEmpty else { return 0 }

        var imported = 0
        for item in pending {
            let all = (try? context.fetch(FetchDescriptor<DiaryEntry>())) ?? []
            if let existing = updatableCheckIn(in: all, on: item.date) {
                existing.mood = item.mood
                existing.updatedAt = Date()
            } else {
                context.insert(DiaryEntry(diaryDate: item.date, mood: item.mood))
            }
            try? context.save()   // commit before the next item re-fetches
            imported += 1
            MoodInbox.remove(item)
        }
        return imported
    }
}
