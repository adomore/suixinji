import Foundation

/// Full-backup format (evolution): a single self-contained JSON file holding
/// every entry plus its media (base64), so it can be exported for safekeeping
/// and re-imported after a reinstall/new device — directly addressing the PRD's
/// "删 App = 数据全部丢失" risk. No ZIP dependency needed.
struct DiaryBackup: Codable {
    var version = 1
    var exportedAt: Date
    var entries: [EntryDTO]
    var media: [MediaDTO]

    struct MediaDTO: Codable {
        let name: String
        let data: Data          // JSON-encoded as base64
    }

    struct EntryDTO: Codable {
        var id: UUID
        var createdAt: Date
        var diaryDate: Date
        var updatedAt: Date
        var text: String
        var mood: String?
        var weather: String?
        var weatherText: String?
        var tags: [String]
        var locationName: String?
        var latitude: Double?
        var longitude: Double?
        var imageFileNames: [String]
        var audioFileName: String?
        var audioDuration: Double?
        /// 私密日记 (evolution). Optional so older backups (without this key) still
        /// decode; treated as `false` when absent.
        var isPrivate: Bool?

        init(from e: DiaryEntry) {
            id = e.id
            createdAt = e.createdAt
            diaryDate = e.diaryDate
            updatedAt = e.updatedAt
            text = e.text
            mood = e.mood
            weather = e.weather
            weatherText = e.weatherText
            tags = e.tags
            locationName = e.locationName
            latitude = e.latitude
            longitude = e.longitude
            imageFileNames = e.imageFileNames
            audioFileName = e.audioFileName
            audioDuration = e.audioDuration
            isPrivate = e.isPrivate
        }

        /// Reconstruct a model object, preserving the original id/timestamps so
        /// re-imports can dedupe by id.
        func makeEntry() -> DiaryEntry {
            let e = DiaryEntry(
                diaryDate: diaryDate, text: text, mood: mood, weather: weather,
                weatherText: weatherText, tags: tags, locationName: locationName,
                latitude: latitude, longitude: longitude,
                imageFileNames: imageFileNames, audioFileName: audioFileName,
                audioDuration: audioDuration, isPrivate: isPrivate ?? false
            )
            e.id = id
            e.createdAt = createdAt
            e.updatedAt = updatedAt
            return e
        }
    }
}
