import Foundation

/// The small, glanceable slice of state the widget needs. The app writes it to
/// the shared App Group container after any change; the widget reads it. Kept
/// tiny on purpose — the widget never touches SwiftData or media.
struct WidgetSnapshot: Codable, Equatable {
    var currentStreak: Int
    var totalEntries: Int
    var wroteToday: Bool
    var generatedAt: Date

    static let empty = WidgetSnapshot(
        currentStreak: 0, totalEntries: 0, wroteToday: false, generatedAt: .distantPast
    )
}
