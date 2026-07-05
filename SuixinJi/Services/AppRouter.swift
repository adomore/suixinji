import Foundation
import CoreSpotlight

/// Lightweight app-wide router for deep links (evolution · Spotlight). When the
/// user taps a diary in system Spotlight, the app is handed an `NSUserActivity`;
/// we stash the target id here and `HomeView` navigates to it.
@MainActor
final class AppRouter: ObservableObject {
    /// The entry a deep link wants to open. HomeView consumes and clears it.
    @Published var pendingEntryID: UUID?

    /// Pull the diary id out of a Spotlight "open this item" activity.
    func handle(_ activity: NSUserActivity) {
        guard activity.activityType == CSSearchableItemActionType,
              let id = activity.userInfo?[CSSearchableItemActivityIdentifierKey] as? String,
              let uuid = UUID(uuidString: id) else { return }
        pendingEntryID = uuid
    }
}
