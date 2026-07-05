import Foundation
import CoreSpotlight
import UniformTypeIdentifiers

/// Indexes diary entries into system **Spotlight** (evolution) so a user can find
/// a diary from the home-screen search, and taps jump straight to it. No special
/// entitlement is needed. Indexing is best-effort — a failure never blocks a save.
enum SpotlightIndexer {
    static let domain = "diary.entry"

    /// Build the searchable item for one entry. Pure (no I/O) so it's unit-testable.
    static func makeItem(for entry: DiaryEntry) -> CSSearchableItem {
        let attrs = CSSearchableItemAttributeSet(contentType: .text)
        attrs.title = title(for: entry)
        let body = entry.text.trimmingCharacters(in: .whitespacesAndNewlines)
        attrs.contentDescription = body.isEmpty ? placeholder(for: entry) : body
        attrs.keywords = keywords(for: entry)
        attrs.contentCreationDate = entry.diaryDate
        return CSSearchableItem(uniqueIdentifier: entry.id.uuidString,
                                domainIdentifier: domain,
                                attributeSet: attrs)
    }

    static func title(for entry: DiaryEntry) -> String {
        let date = DiaryDateFormat.shortChinese(entry.diaryDate)
        let firstLine = entry.text.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        let snippet = firstLine.prefix(20)
        return snippet.isEmpty ? date : "\(date) · \(snippet)"
    }

    static func keywords(for entry: DiaryEntry) -> [String] {
        var kw = entry.tags
        if let mood = entry.mood { kw.append(mood) }
        if let place = entry.locationName, !place.isEmpty { kw.append(place) }
        if let weather = entry.weatherText, !weather.isEmpty { kw.append(weather) }
        return kw
    }

    private static func placeholder(for entry: DiaryEntry) -> String {
        if !entry.imageFileNames.isEmpty && entry.hasAudio { return "图片 · 录音" }
        if !entry.imageFileNames.isEmpty { return "图片日记" }
        if entry.hasAudio { return "语音日记" }
        return "日记"
    }

    // MARK: Side-effecting index maintenance (best-effort)

    static func index(_ entry: DiaryEntry) {
        CSSearchableIndex.default().indexSearchableItems([makeItem(for: entry)])
    }

    static func remove(id: UUID) {
        CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: [id.uuidString])
    }

    /// Rebuild the whole index from the current entries (called on launch). Clears
    /// this app's domain first so deleted-while-away entries don't linger.
    static func reindexAll(_ entries: [DiaryEntry]) {
        let index = CSSearchableIndex.default()
        index.deleteSearchableItems(withDomainIdentifiers: [domain]) { _ in
            index.indexSearchableItems(entries.map(makeItem(for:)))
        }
    }
}
