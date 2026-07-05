import Foundation
#if canImport(EventKit)
import EventKit
#endif

/// 日历联动 (evolution). Reads the day's calendar events and formats them as a text
/// block the editor can drop in at the caret ("带入今天的日程").
///
/// Read-only: the app only reads events, never creates or edits them. Permission-gated
/// (asked on first use), and the text formatting is pure & unit-testable.
@MainActor
final class CalendarService {
    static let shared = CalendarService()

    /// A calendar event reduced to what we actually render — keeps the pure formatter
    /// free of EventKit so it can be unit-tested.
    struct EventItem: Equatable {
        let title: String
        let start: Date
        let isAllDay: Bool
    }

    #if canImport(EventKit)
    private let store = EKEventStore()

    /// Ask for read access to Calendar. iOS 17 split access into full/write-only;
    /// reading events needs *full* access.
    func requestAccess() async -> Bool {
        do {
            return try await store.requestFullAccessToEvents()
        } catch {
            return false
        }
    }

    /// True once the user has granted full calendar access.
    var isAuthorized: Bool {
        EKEventStore.authorizationStatus(for: .event) == .fullAccess
    }

    /// The events occurring on the calendar day containing `day`, sorted by start.
    func events(on day: Date, calendar: Calendar = .current) -> [EventItem] {
        guard let range = Self.dayBounds(day, calendar: calendar) else { return [] }
        let predicate = store.predicateForEvents(withStart: range.start, end: range.end, calendars: nil)
        return store.events(matching: predicate)
            .sorted { $0.startDate < $1.startDate }
            .map { EventItem(title: $0.title ?? "", start: $0.startDate, isAllDay: $0.isAllDay) }
    }
    #else
    func requestAccess() async -> Bool { false }
    var isAuthorized: Bool { false }
    func events(on day: Date, calendar: Calendar = .current) -> [EventItem] { [] }
    #endif

    // MARK: - Pure formatting (testable)

    /// Render events as a diary-friendly block, e.g.:
    /// ```
    /// 今天的日程：
    /// · 09:00 晨会
    /// · 全天 出差
    /// ```
    /// Returns "" when there are no events (caller shows a friendly notice instead).
    nonisolated static func summary(for events: [EventItem], locale: Locale = .current,
                                    calendar: Calendar = .current) -> String {
        guard !events.isEmpty else { return "" }
        let f = DateFormatter()
        f.locale = locale
        f.calendar = calendar
        f.dateFormat = "HH:mm"
        let lines = events.map { e -> String in
            let title = e.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let name = title.isEmpty ? "（无标题）" : title
            let time = e.isAllDay ? "全天" : f.string(from: e.start)
            return "· \(time) \(name)"
        }
        return (["今天的日程："] + lines).joined(separator: "\n")
    }

    nonisolated static func dayBounds(_ day: Date, calendar: Calendar = .current) -> (start: Date, end: Date)? {
        let start = calendar.startOfDay(for: day)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return nil }
        return (start, end)
    }
}
