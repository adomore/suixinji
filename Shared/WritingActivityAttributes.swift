import Foundation
import ActivityKit

/// Live Activity · 写作计时 (evolution). Describes a focused writing session shown
/// on the Lock Screen / Dynamic Island. The elapsed timer runs itself via
/// `Text(timerInterval:)` (no pushes); only the character count is pushed as the
/// dynamic `ContentState`. Compiled into the app (starts/updates it) and the
/// widget extension (renders it).
struct WritingActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var characters: Int
    }

    /// When the session started — the timer counts up from here.
    var startDate: Date
}
