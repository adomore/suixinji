import Foundation
import SwiftData

/// Bridges local media files (`FileStore`) and the synced `MediaBlob` records so
/// photos & recordings ride iCloud with the diary text (F11, media step).
///
/// ## Why uploads are NOT inferred during reconcile
/// CloudKit propagates the deletion of the entry record and the deletion of the
/// blob record **independently and unordered**. If `reconcile` re-uploaded a blob
/// whenever "an entry references a file that has no blob," then on a second device
/// — where the blob-deletion arrived before the entry-deletion — it would
/// *resurrect* just-deleted media and push it back to every device. So uploads
/// are driven **only** by authoritative local actions:
///   • `DiaryService.save` → `syncUp` (new media) / `removeBlobs` (dropped media),
///   • a **one-time migration** that seeds the cloud with media that already
///     existed locally before this feature shipped.
/// After migration, `reconcile` only ever **downloads** (materializes arrived
/// blobs) and **cleans orphans** — it never creates or, on its own, resurrects.
///
/// ## Orphan cleanup is race-safe
/// A local media file exists only because this device either created it (its entry
/// is local) or downloaded it (its blob is local). So a file referenced by **no
/// entry AND no blob** can only mean *both* were deleted and have settled here —
/// safe to reclaim. During an in-flight delete (blob gone, entry not yet) the file
/// is still entry-referenced and is kept; the reverse keeps it blob-backed.
///
/// Invariant used by `removeBlobs`: a media file name is a per-entry UUID (see
/// `FileStore.saveImage`/`adoptAudio`), so a blob backs exactly one entry.
enum MediaSyncService {
    static let migrationKey = "mediaSyncMigratedV1"

    /// Two-way, resurrection-safe pass: materialize arrived blobs, run the
    /// one-time upload migration, then reclaim orphan files. Cheap when idle.
    /// Call on launch and on app-active, after CloudKit has had time to merge.
    static func reconcile(context: ModelContext,
                          fileStore: FileStoreImpl = FileStore.shared,
                          defaults: UserDefaults = .standard) {
        download(context: context, fileStore: fileStore)
        migrateIfNeeded(context: context, fileStore: fileStore, defaults: defaults)
        cleanupOrphans(context: context, fileStore: fileStore)
    }

    // MARK: Download (synced blob → local file)

    /// Write out any blob whose local file is missing. Only faults in `blob.data`
    /// for files that are actually absent, so present media stays lazy.
    private static func download(context: ModelContext, fileStore: FileStoreImpl) {
        let fm = FileManager.default
        for blob in allBlobs(context) {
            let url = mediaURL(for: blob.name, fileStore: fileStore)
            if !fm.fileExists(atPath: url.path) {
                try? fileStore.writeMedia(name: blob.name, data: blob.data)
            }
        }
    }

    // MARK: One-time migration (pre-existing local media → cloud)

    /// Seed the cloud once with media that already existed locally before media
    /// sync shipped. Guarded by a flag so it never re-fires (which would risk the
    /// resurrection this design avoids). New media created after upgrade uploads
    /// via `syncUp`, not here.
    private static func migrateIfNeeded(context: ModelContext, fileStore: FileStoreImpl, defaults: UserDefaults) {
        guard !defaults.bool(forKey: migrationKey) else { return }
        let fm = FileManager.default
        var existing = Set(allBlobs(context).map(\.name))
        var didInsert = false
        var hadReadFailure = false // a file that IS on disk but couldn't be read
        for entry in allEntries(context) {
            for name in referencedNames(of: entry) where !existing.contains(name) {
                let url = mediaURL(for: name, fileStore: fileStore)
                // Not on disk yet (its blob hasn't arrived) is the normal case —
                // skip without blocking the flag. A present-but-unreadable file is
                // a transient failure worth retrying, so hold the flag back.
                guard fm.fileExists(atPath: url.path) else { continue }
                guard let data = try? Data(contentsOf: url) else { hadReadFailure = true; continue }
                context.insert(MediaBlob(name: name, kind: MediaBlob.Kind.of(name), data: data))
                existing.insert(name)
                didInsert = true
            }
        }
        if didInsert { try? context.save() }
        if !hadReadFailure { defaults.set(true, forKey: migrationKey) } // else retry next launch
    }

    // MARK: Orphan cleanup (local file referenced by nothing → reclaim)

    private static func cleanupOrphans(context: ModelContext, fileStore: FileStoreImpl) {
        var keep = Set(allBlobs(context).map(\.name))            // blob-backed → keep
        for entry in allEntries(context) { keep.formUnion(referencedNames(of: entry)) } // referenced → keep
        let fm = FileManager.default
        for dir in [fileStore.imagesDir, fileStore.audiosDir] {
            guard let files = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { continue }
            for url in files where !keep.contains(url.lastPathComponent) {
                try? fm.removeItem(at: url)
            }
        }
    }

    // MARK: Authoritative per-action hooks (called from DiaryService)

    /// Upload one entry's media right after it's saved, so new photos/voice memos
    /// start syncing immediately. Skips names that already have a blob.
    static func syncUp(_ entry: DiaryEntry, context: ModelContext, fileStore: FileStoreImpl = FileStore.shared) {
        let names = referencedNames(of: entry)
        guard !names.isEmpty else { return }
        let existing = existingBlobNames(in: context, among: names)
        var didInsert = false
        for name in names where !existing.contains(name) {
            if insertBlob(named: name, context: context, fileStore: fileStore) { didInsert = true }
        }
        if didInsert { try? context.save() }
    }

    /// Delete the synced blobs for the given media names (called when an entry is
    /// deleted or an image is dropped in the editor). Safe without a cross-entry
    /// check: each name is a per-entry UUID. The caller saves the context.
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

    /// Read a local media file and insert a `MediaBlob` for it. Returns false if
    /// the file isn't on disk yet (e.g. its blob hasn't arrived) — nothing to upload.
    @discardableResult
    private static func insertBlob(named name: String, context: ModelContext, fileStore: FileStoreImpl) -> Bool {
        let url = mediaURL(for: name, fileStore: fileStore)
        guard let data = try? Data(contentsOf: url) else { return false }
        context.insert(MediaBlob(name: name, kind: MediaBlob.Kind.of(name), data: data))
        return true
    }

    private static func mediaURL(for name: String, fileStore: FileStoreImpl) -> URL {
        MediaBlob.Kind.of(name) == MediaBlob.Kind.audio ? fileStore.audioURL(name) : fileStore.imageURL(name)
    }

    private static func allBlobs(_ context: ModelContext) -> [MediaBlob] {
        (try? context.fetch(FetchDescriptor<MediaBlob>())) ?? []
    }

    private static func allEntries(_ context: ModelContext) -> [DiaryEntry] {
        (try? context.fetch(FetchDescriptor<DiaryEntry>())) ?? []
    }

    private static func existingBlobNames(in context: ModelContext, among names: [String]) -> Set<String> {
        let descriptor = FetchDescriptor<MediaBlob>(predicate: #Predicate { names.contains($0.name) })
        let blobs = (try? context.fetch(descriptor)) ?? []
        return Set(blobs.map(\.name))
    }
}
