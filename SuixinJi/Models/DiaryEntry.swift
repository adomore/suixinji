import Foundation
import SwiftData

/// A single diary entry. Mirrors the data model in 随心记-PRD.md §5.2.
///
/// Golden rule from the PRD: the database stores only *file names*, never the
/// binary blobs. The real images/audio live in the app sandbox (see `FileStore`).
@Model
final class DiaryEntry {
    var id: UUID = UUID()
    /// Creation timestamp — the list is sorted by this (survives clock changes).
    var createdAt: Date = Date()
    /// The date the entry "belongs to" (defaults to today, user-editable for back-dating).
    var diaryDate: Date = Date()
    var updatedAt: Date = Date()
    var text: String = ""
    /// Mood emoji (P1 · F7), e.g. "😊". nil = not set.
    var mood: String?
    /// Weather emoji (P2 · F14), e.g. "☀️". nil = not set.
    var weather: String?
    /// Free-form tags (P2 · F14). Empty = none.
    var tags: [String] = []
    /// Reverse-geocoded place name (P2 · F14), e.g. "杭州市西湖区". nil = none.
    var locationName: String?
    var latitude: Double?
    var longitude: Double?
    /// e.g. `["9F2A….jpg"]`; empty when there are no photos. Max 9 (F4).
    var imageFileNames: [String] = []
    /// Recording file name (`.m4a`), or nil. Max 1 per entry (F3).
    var audioFileName: String?
    /// Recording length in seconds — drives the badge / playback bar.
    var audioDuration: Double?

    init(
        diaryDate: Date = Date(),
        text: String = "",
        mood: String? = nil,
        weather: String? = nil,
        tags: [String] = [],
        locationName: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        imageFileNames: [String] = [],
        audioFileName: String? = nil,
        audioDuration: Double? = nil
    ) {
        let now = Date()
        self.id = UUID()
        self.createdAt = now
        self.diaryDate = diaryDate
        self.updatedAt = now
        self.text = text
        self.mood = mood
        self.weather = weather
        self.tags = tags
        self.locationName = locationName
        self.latitude = latitude
        self.longitude = longitude
        self.imageFileNames = imageFileNames
        self.audioFileName = audioFileName
        self.audioDuration = audioDuration
    }

    var hasAudio: Bool { audioFileName != nil }

    /// Save is only allowed when there is text, a photo, or a recording (F1 rule).
    var hasContent: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !imageFileNames.isEmpty
            || audioFileName != nil
    }
}
