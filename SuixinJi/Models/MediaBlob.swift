import Foundation
import SwiftData

/// A synced copy of one media file (image/audio), so photos & recordings ride
/// iCloud alongside the diary records (F11, media step).
///
/// Why a sidecar model instead of putting bytes on `DiaryEntry`:
///  • The whole app reads media by *file name* from `FileStore` (PRD §5.3 golden
///    rule). Keeping that untouched, `MediaBlob` mirrors each file keyed by its
///    name; `MediaSyncService` reconciles blobs ⇄ local files in both directions.
///  • `@Attribute(.externalStorage)` keeps the bytes out of the SQLite row
///    locally and, under SwiftData+CloudKit, syncs them as a **CKAsset**.
///
/// CloudKit-compatible by construction: every attribute is defaulted, there are
/// no unique constraints (media names are globally-unique UUIDs, so a name maps
/// to exactly one entry — see `MediaSyncService`), and no relationships.
@Model
final class MediaBlob {
    /// The file name, e.g. `"9F2A….jpg"` / `"…​.m4a"` — the logical key that ties
    /// this blob to `DiaryEntry.imageFileNames` / `audioFileName`.
    var name: String = ""
    /// `"image"` or `"audio"` — routes materialization to the right sandbox dir.
    var kind: String = "image"
    /// The file bytes. External storage → CKAsset under CloudKit.
    @Attribute(.externalStorage) var data: Data = Data()
    var createdAt: Date = Date()

    init(name: String, kind: String, data: Data) {
        self.name = name
        self.kind = kind
        self.data = data
        self.createdAt = Date()
    }

    enum Kind {
        static let image = "image"
        static let audio = "audio"
        /// Route a file name to its kind by extension (matches `FileStore`).
        static func of(_ name: String) -> String {
            name.lowercased().hasSuffix(".m4a") ? audio : image
        }
    }
}
