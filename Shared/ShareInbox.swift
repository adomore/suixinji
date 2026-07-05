import Foundation

/// Cross-process inbox for the Share Extension (evolution). The extension is a
/// dumb writer: it drops shared text + image files into the App Group container.
/// The main app drains this inbox into new diary entries on launch. Both targets
/// compile this file. Kept deliberately free of SwiftData/UIKit so the extension
/// stays tiny.
enum ShareInbox {
    /// One shared payload waiting to be imported.
    struct PendingShare: Codable, Equatable {
        var id: String
        var text: String
        var imageFileNames: [String]   // files stored alongside, in the inbox dir
        var createdAt: Date
    }

    private static var dir: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: SharedStore.appGroup)?
            .appendingPathComponent("ShareInbox", isDirectory: true)
    }

    // MARK: Extension side — write

    /// Persist one shared payload (text + up to 9 images) for the app to import.
    static func write(text: String, imageDatas: [Data]) {
        guard let dir else { return }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let id = UUID().uuidString
        var names: [String] = []
        for data in imageDatas.prefix(9) {                 // F4: max 9 images
            let name = "\(UUID().uuidString).img"
            if (try? data.write(to: dir.appendingPathComponent(name), options: .atomic)) != nil {
                names.append(name)
            }
        }
        let share = PendingShare(id: id, text: text, imageFileNames: names, createdAt: Date())
        if let encoded = try? JSONEncoder().encode(share) {
            try? encoded.write(to: dir.appendingPathComponent("\(id).json"), options: .atomic)
        }
    }

    // MARK: App side — drain

    /// All pending shares, oldest first.
    static func pending() -> [PendingShare] {
        guard let dir,
              let files = try? FileManager.default.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: nil) else { return [] }
        let decoder = JSONDecoder()
        return files
            .filter { $0.pathExtension == "json" }
            .compactMap { (try? Data(contentsOf: $0)).flatMap { try? decoder.decode(PendingShare.self, from: $0) } }
            .sorted { $0.createdAt < $1.createdAt }
    }

    /// The raw bytes of one inbox image file.
    static func imageData(_ name: String) -> Data? {
        guard let dir else { return nil }
        return try? Data(contentsOf: dir.appendingPathComponent(name))
    }

    /// Remove a share's json + image files once imported.
    static func remove(_ share: PendingShare) {
        guard let dir else { return }
        let fm = FileManager.default
        try? fm.removeItem(at: dir.appendingPathComponent("\(share.id).json"))
        for name in share.imageFileNames {
            try? fm.removeItem(at: dir.appendingPathComponent(name))
        }
    }
}
