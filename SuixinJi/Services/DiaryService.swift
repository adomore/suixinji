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
        let entry = existing ?? DiaryEntry(diaryDate: draft.diaryDate)

        // Track what THIS call writes so a mid-way failure can be rolled back —
        // no phantom entry, no orphan files (PRD §9: never silently drop data).
        var writtenImages: [String] = []
        var adoptedAudio: String?
        var inserted = false

        do {
            // 1) Write all new files FIRST (nothing touches the DB yet).
            var finalImageNames: [String] = []
            for image in draft.images {
                switch image {
                case .existing(let name):
                    finalImageNames.append(name)
                case .new(let uiImage, _):
                    let name = try fileStore.saveImage(uiImage)
                    writtenImages.append(name)
                    finalImageNames.append(name)
                }
            }

            var audioName = existing?.audioFileName
            var audioDuration = existing?.audioDuration
            switch draft.audio {
            case .none:
                audioName = nil; audioDuration = nil
            case .existing(let name, let duration)?:
                audioName = name; audioDuration = duration
            case .new(let url, let duration)?:
                let name = try fileStore.adoptAudio(tempURL: url)
                adoptedAudio = name
                audioName = name; audioDuration = duration
            }

            // 2) All writes succeeded — mutate the model and commit.
            let oldImages = existing?.imageFileNames ?? []
            let oldAudio = existing?.audioFileName
            if existing == nil { context.insert(entry); inserted = true }
            entry.imageFileNames = finalImageNames
            entry.audioFileName = audioName
            entry.audioDuration = audioDuration
            entry.text = draft.text
            entry.diaryDate = draft.diaryDate
            entry.mood = draft.mood
            entry.weather = draft.weather
            entry.weatherText = draft.weatherText
            entry.tags = draft.tags
            entry.locationName = draft.locationName
            entry.latitude = draft.latitude
            entry.longitude = draft.longitude
            entry.updatedAt = Date()
            try context.save()

            // 3) Only after a successful commit, delete files no longer referenced.
            let kept = Set(finalImageNames)
            var droppedNames: [String] = oldImages.filter { !kept.contains($0) }
            for old in droppedNames { fileStore.deleteImage(old) }
            if let oldAudio, oldAudio != audioName { fileStore.deleteAudio(oldAudio); droppedNames.append(oldAudio) }

            // 4) Sync (F11 media): push this entry's current media, drop blobs for
            //    media it no longer references. Best-effort — never fails the save.
            MediaSyncService.syncUp(entry, context: context, fileStore: fileStore)
            MediaSyncService.removeBlobs(named: droppedNames, context: context)
            try? context.save()
            return entry
        } catch {
            // Roll back everything this call created.
            for name in writtenImages { fileStore.deleteImage(name) }
            if let adoptedAudio { fileStore.deleteAudio(adoptedAudio) }
            if inserted { context.delete(entry) }
            throw error
        }
    }

    /// Delete an entry and its files. Files first, then the record (§5.3), so no
    /// orphans remain. Stop any playback of this entry's audio *before* calling.
    static func delete(
        _ entry: DiaryEntry,
        from context: ModelContext,
        fileStore: FileStoreImpl = FileStore.shared
    ) throws {
        let mediaNames = MediaSyncService.referencedNames(of: entry)
        fileStore.deleteFiles(for: entry)
        MediaSyncService.removeBlobs(named: mediaNames, context: context) // F11: drop synced copies too
        context.delete(entry)
        try context.save()
    }
}
