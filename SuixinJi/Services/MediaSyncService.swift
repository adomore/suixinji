import Foundation
import SwiftData

/// Bridges local media files (`FileStore`) and the synced `MediaBlob` records so
/// photos & recordings ride iCloud with the diary text (F11, media step).
///
/// Two race-safe directions, run by `reconcile`:
///  • **Download** — for every `MediaBlob` whose local file is missing, write the
///    bytes back into the sandbox. This is how a second device gets its media.
///  • **Upload** — for every media file a `DiaryEntry` references that has a local
///    file but no `MediaBlob` yet, create the blob so CloudKit uploads it.
///
/// Safety rests on one invariant: **a media file name is a UUID owned by exactly
/// one entry** (created in `FileStore.saveImage`/`adoptAudio`). So a blob can only
/// ever back one entry — no cross-device "is anyone else using this?" race. That
/// lets `removeBlobs(for:)` delete an entry's blobs on delete without waiting for
/// other devices to sync, and lets upload skip files that haven't arrived yet
/// (their blob is materialized first, then upload sees it exists and skips).
enum MediaSyncService {

    /// Full two-way pass. Cheap when there's nothing to do (only faults in blob
    /// bytes for files that are actually missing locally). Call on launch and
    /// when the app becomes active, after CloudKit has had a chance to merge.
    static func reconcile(context: ModelContext, fileStore: FileStoreImpl = FileStore.shared) {
        let fm = FileManager.default
        let blobs = (try? context.fetch(FetchDescriptor<MediaBlob>())) ?? []

        // 1) Download: materialize any blob whose local file is missing.
        var blobNames = Set<String>()
        for blob in blobs {
            blobNames.insert(blob.name)
            let url = blob.kind == MediaBlob.Kind.audio
                ? fileStore.audioURL(blob.name) : fileStore.imageURL(blob.name)
            if !fm.fileExists(atPath: url.path) {
                try? fileStore.writeMedia(name: blob.name, data: blob.data) // faults in bytes here
            }
        }

        // 2) Upload: create a blob for each referenced local file not yet synced.
        let entries = (try? context.fetch(FetchDescriptor<DiaryEntry>())) ?? []
        var didInsert = false
        for entry in entries {
            for name in referencedNames(of: entry) where !blobNames.contains(name) {
                let kind = MediaBlob.Kind.of(name)
                let url = kind == MediaBlob.Kind.audio ? fileStore.audioURL(name) : fileStore.imageURL(name)
                guard let data = try? Data(contentsOf: url) else { continue } // no local file yet → its blob will arrive
                context.insert(MediaBlob(name: name, kind: kind, data: data))
                blobNames.insert(name)
                didInsert = true
            }
        }
        if didInsert { try? context.save() }
    }

    /// Upload just one entry's media right after it's saved, so a new photo/voice
    /// memo starts syncing immediately instead of waiting for the next reconcile.
    static func syncUp(_ entry: DiaryEntry, context: ModelContext, fileStore: FileStoreImpl = FileStore.shared) {
        let names = referencedNames(of: entry)
        guard !names.isEmpty else { return }
        let existing = existingBlobNames(in: context, among: names)
        var didInsert = false
        for name in names where !existing.contains(name) {
            let kind = MediaBlob.Kind.of(name)
            let url = kind == MediaBlob.Kind.audio ? fileStore.audioURL(name) : fileStore.imageURL(name)
            guard let data = try? Data(contentsOf: url) else { continue }
            context.insert(MediaBlob(name: name, kind: kind, data: data))
            didInsert = true
        }
        if didInsert { try? context.save() }
    }

    /// Delete the synced blobs for the given media names (called when an entry is
    /// deleted). Safe without a cross-entry check: each name is owned by one entry.
    /// The caller saves the context.
    static func removeBlobs(named names: [String], context: ModelContext) {
        guard !names.isEmpty else { return }
        let descriptor = FetchDescriptor<MediaBlob>(predicate: #Predicate { names.contains($0.name) })
        guard let blobs = try? context.fetch(descriptor) else { return }
        for blob in blobs { context.delete(blob) }
    }

    // MARK: Helpers

    static func referencedNames(of entry: DiaryEntry) -> [String] {
        var names = entry.imageFileNames
        if let audio = entry.audioFileName { names.append(audio) }
        return names
    }

    private static func existingBlobNames(in context: ModelContext, among names: [String]) -> Set<String> {
        let descriptor = FetchDescriptor<MediaBlob>(predicate: #Predicate { names.contains($0.name) })
        let blobs = (try? context.fetch(descriptor)) ?? []
        return Set(blobs.map(\.name))
    }
}
