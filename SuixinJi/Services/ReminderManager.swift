import Foundation
import UserNotifications

/// Daily "该写日记啦" local notification (F10). No server — a single repeating
/// calendar notification the user can toggle and time in Settings.
enum ReminderManager {
    static let identifier = "suixinji.daily.reminder"

    /// Ask for notification permission. Returns whether it was granted.
    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// (Re)schedule the daily reminder at `hour:minute` (local time).
    static func schedule(hour: Int, minute: Int) {
        let content = UNMutableNotificationContent()
        content.title = "随心记"
        content.body = "该写日记啦，记录今天的心情吧。"
        content.sound = .default

        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.add(request)
    }

    static func cancel() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    /// Parse a stored "HH:mm" string into components (defaults to 21:00).
    static func parse(_ time: String) -> (hour: Int, minute: Int) {
        let parts = time.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return (21, 0) }
        return (min(max(parts[0], 0), 23), min(max(parts[1], 0), 59))
    }
}
