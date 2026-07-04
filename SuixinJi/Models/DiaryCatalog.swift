import Foundation

/// Fixed emoji palettes for mood (F7) and weather (F14), plus the search filter.
/// Kept tiny and system-font-only per the Brief (no custom art).
enum DiaryCatalog {
    /// Daylio-style mood set — one tap records the day's feeling.
    static let moods = ["😊", "🙂", "😐", "😔", "😢", "😡", "😴", "🥳"]

    /// Weather set — the manual picker, and also the exact emojis WeatherKit
    /// results map onto (`WeatherProvider.describe`), so display stays consistent.
    static let weathers = ["☀️", "🌤️", "☁️", "🌧️", "⛈️", "❄️", "🌫️", "🌬️"]
}

/// Local keyword search (F8): matches text, tags, mood, weather and location.
enum DiarySearch {
    static func filter(_ entries: [DiaryEntry], query: String) -> [DiaryEntry] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return entries }
        let needle = q.lowercased()
        return entries.filter { entry in
            if entry.text.lowercased().contains(needle) { return true }
            if entry.tags.contains(where: { $0.lowercased().contains(needle) }) { return true }
            if let m = entry.mood, m.contains(q) { return true }
            if let w = entry.weather, w.contains(q) { return true }
            if let loc = entry.locationName, loc.lowercased().contains(needle) { return true }
            return false
        }
    }
}
