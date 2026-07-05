import Foundation

/// Cross-process inbox for the 快速心情打卡 widget (evolution). The widget's mood
/// button is a dumb writer: it drops a pending mood check-in into the App Group
/// container and records the latest one for its own display. The main app drains
/// the pending check-ins into diary entries when it next becomes active.
/// Both targets compile this file. No SwiftData / UIKit so the widget stays tiny.
enum MoodInbox {
    /// One mood check-in waiting to be imported.
    struct PendingMood: Codable, Equatable {
        var id: String
        var mood: String
        var date: Date
    }

    private static var dir: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: SharedStore.appGroup)?
            .appendingPathComponent("MoodInbox", isDirectory: true)
    }

    private static var lastURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: SharedStore.appGroup)?
            .appendingPathComponent("mood-last.json")
    }

    // MARK: Widget side — write

    /// Record a mood check-in for the app to import, and remember it as the latest
    /// so the widget can show a "recorded" state immediately.
    static func write(mood: String, date: Date = Date()) {
        guard let dir else { return }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let pending = PendingMood(id: UUID().uuidString, mood: mood, date: date)
        if let encoded = try? JSONEncoder().encode(pending) {
            try? encoded.write(to: dir.appendingPathComponent("\(pending.id).json"), options: .atomic)
            if let lastURL { try? encoded.write(to: lastURL, options: .atomic) }
        }
    }

    /// The most recent check-in (for the widget's display). nil if none yet.
    static func last() -> PendingMood? {
        guard let lastURL,
              let data = try? Data(contentsOf: lastURL),
              let pending = try? JSONDecoder().decode(PendingMood.self, from: data) else { return nil }
        return pending
    }

    // MARK: App side — drain

    /// All pending check-ins, oldest first.
    static func pending() -> [PendingMood] {
        guard let dir,
              let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
        else { return [] }
        let decoder = JSONDecoder()
        return files
            .filter { $0.pathExtension == "json" }
            .compactMap { (try? Data(contentsOf: $0)).flatMap { try? decoder.decode(PendingMood.self, from: $0) } }
            .sorted { $0.date < $1.date }
    }

    /// Remove one check-in's file once imported.
    static func remove(_ pending: PendingMood) {
        guard let dir else { return }
        try? FileManager.default.removeItem(at: dir.appendingPathComponent("\(pending.id).json"))
    }
}
