import Foundation
import SwiftData

/// Export/import the whole diary as one self-contained JSON file (evolution).
/// Testable with an in-memory `ModelContext` + a temp `FileStore`.
enum BackupService {
    struct ImportResult: Equatable {
        var imported: Int
        var skipped: Int
    }

    private static func encoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }
    private static func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    // MARK: Export

    static func makeBackup(from entries: [DiaryEntry], fileStore: FileStoreImpl, now: Date) -> DiaryBackup {
        var names = Set<String>()
        for e in entries {
            names.formUnion(e.imageFileNames)
            if let a = e.audioFileName { names.insert(a) }
        }
        let media: [DiaryBackup.MediaDTO] = names.sorted().compactMap { name in
            let url = name.lowercased().hasSuffix(".m4a") ? fileStore.audioURL(name) : fileStore.imageURL(name)
            guard let data = try? Data(contentsOf: url) else { return nil } // missing file → skip blob
            return DiaryBackup.MediaDTO(name: name, data: data)
        }
        return DiaryBackup(version: 1, exportedAt: now,
                           entries: entries.map(DiaryBackup.EntryDTO.init(from:)),
                           media: media)
    }

    static func exportData(from entries: [DiaryEntry], fileStore: FileStoreImpl = FileStore.shared,
                           now: Date = Date()) throws -> Data {
        try encoder().encode(makeBackup(from: entries, fileStore: fileStore, now: now))
    }

    /// Write a backup to a temp file and return its URL (for the share sheet).
    /// A non-empty `password` encrypts it (AES-GCM) → `.suixinji`; otherwise `.json`.
    static func writeBackupFile(from entries: [DiaryEntry], fileStore: FileStoreImpl = FileStore.shared,
                                now: Date = Date(), password: String? = nil) throws -> URL {
        var data = try exportData(from: entries, fileStore: fileStore, now: now)
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"
        let ext: String
        if let password, !password.isEmpty {
            data = try BackupCrypto.encrypt(data, password: password)
            ext = "suixinji"
        } else {
            ext = "json"
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("随心记备份-\(f.string(from: now)).\(ext)")
        try data.write(to: url, options: .atomic)
        return url
    }

    // MARK: Import (merge by id — never overwrites/dedupes existing entries)

    @discardableResult
    static func importData(_ raw: Data, into context: ModelContext,
                           fileStore: FileStoreImpl = FileStore.shared,
                           password: String? = nil) throws -> ImportResult {
        // Decrypt first if this is an encrypted backup (needs the password).
        let data: Data
        if BackupCrypto.isEncrypted(raw) {
            guard let password, !password.isEmpty else { throw BackupCrypto.CryptoError.wrongPassword }
            data = try BackupCrypto.decrypt(raw, password: password)
        } else {
            data = raw
        }
        let backup = try decoder().decode(DiaryBackup.self, from: data)
        let existingIDs = Set(try context.fetch(FetchDescriptor<DiaryEntry>()).map(\.id))
        let mediaByName = Dictionary(backup.media.map { ($0.name, $0.data) }, uniquingKeysWith: { first, _ in first })

        var imported = 0, skipped = 0
        for dto in backup.entries {
            guard !existingIDs.contains(dto.id) else { skipped += 1; continue }
            // Restore referenced media (best-effort; a missing blob just leaves a
            // broken thumbnail rather than failing the whole import).
            for name in dto.imageFileNames {
                if let blob = mediaByName[name] { try? fileStore.writeMedia(name: name, data: blob) }
            }
            if let audio = dto.audioFileName, let blob = mediaByName[audio] {
                try? fileStore.writeMedia(name: audio, data: blob)
            }
            context.insert(dto.makeEntry())
            imported += 1
        }
        try context.save()
        return ImportResult(imported: imported, skipped: skipped)
    }
}
