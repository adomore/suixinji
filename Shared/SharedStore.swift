import Foundation
import WidgetKit

/// Reads/writes the widget snapshot in the shared App Group container, so the
/// app (writer) and the widget extension (reader) can exchange it across
/// processes. Both targets compile this file.
enum SharedStore {
    /// Must match the App Group id in both targets' entitlements.
    static let appGroup = "group.com.zengmingjiang.suixinji"

    private static var snapshotURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appendingPathComponent("widget-snapshot.json")
    }

    /// Called by the app after data changes; also nudges WidgetKit to reload.
    static func write(_ snapshot: WidgetSnapshot) {
        guard let url = snapshotURL,
              let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: url, options: .atomic)
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Read by the widget's timeline provider. Returns `.empty` if unavailable
    /// (e.g. App Group not provisioned) so the widget still renders.
    static func read() -> WidgetSnapshot {
        guard let url = snapshotURL,
              let data = try? Data(contentsOf: url),
              let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
        else { return .empty }
        return snapshot
    }
}
