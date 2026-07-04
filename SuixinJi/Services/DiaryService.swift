import Foundation
import SwiftData

/// The persistence core, extracted from the views so it can be unit-tested with
/// an in-memory `ModelContainer` and a temp `FileStore`. Encapsulates the two
/// rules the PRD cares about most (§5.3):
///  • on save, write new files and delete files the user removed;
///  • on delete, remove the associated files **before** the DB record.
enum DiaryService {

    /// Create (when `existing == nil`) or update a diary entry from a draft.
    /// Writes new images/audio to `fileStore`, deletes ones the user dropped,
    /// then persists. Returns the saved entry. Throws if a file write fails
    /// (e.g. storage full) — callers surface that instead of dropping data (§9).
    @discardableResult
    static func save(
        _ draft: DiaryDraft,
        existing: DiaryEntry?,
        into context: ModelContext,
        fileStore: FileStoreImpl = FileStore.shared
    ) throws -> DiaryEntry {
        let entry: DiaryEntry
        if let existing {
            entry = existing
        } else {
            entry = DiaryEntry(diaryDate: draft.diaryDate)
            context.insert(entry)
        }

        // Images: delete removed-existing, write new, keep order.
        let keptExisting = Set(draft.images.compactMap { image -> String? in
            if case .existing(let name) = image { return name } else { return nil }
        })
        for old in entry.imageFileNames where !keptExisting.contains(old) {
            fileStore.deleteImage(old)
        }
        var finalNames: [String] = []
        for image in draft.images {
            switch image {
            case .existing(let name): finalNames.append(name)
            case .new(let uiImage, _): finalNames.append(try fileStore.saveImage(uiImage))
            }
        }
        entry.imageFileNames = finalNames

        // Audio (max 1 per entry).
        switch draft.audio {
        case .none:
            if let old = entry.audioFileName {
                fileStore.deleteAudio(old)
                entry.audioFileName = nil
                entry.audioDuration = nil
            }
        case .existing(let name, let duration)?:
            entry.audioFileName = name
            entry.audioDuration = duration
        case .new(let url, let duration)?:
            if let old = entry.audioFileName { fileStore.deleteAudio(old) }
            entry.audioFileName = try fileStore.adoptAudio(tempURL: url)
            entry.audioDuration = duration
        }

        entry.text = draft.text
        entry.diaryDate = draft.diaryDate
        entry.mood = draft.mood
        entry.weather = draft.weather
        entry.tags = draft.tags
        entry.locationName = draft.locationName
        entry.latitude = draft.latitude
        entry.longitude = draft.longitude
        entry.updatedAt = Date()
        try context.save()
        return entry
    }

    /// Delete an entry and its files. Files first, then the record (§5.3), so no
    /// orphans remain. Stop any playback of this entry's audio *before* calling.
    static func delete(
        _ entry: DiaryEntry,
        from context: ModelContext,
        fileStore: FileStoreImpl = FileStore.shared
    ) throws {
        fileStore.deleteFiles(for: entry)
        context.delete(entry)
        try context.save()
    }
}
