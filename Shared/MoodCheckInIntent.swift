import AppIntents
import WidgetKit

/// 快速心情打卡 (evolution). Tapping a mood on the widget runs this silently (no app
/// launch): it records the check-in into the App Group inbox and reloads the widget
/// so it can show the "recorded" state. The app turns pending check-ins into diary
/// entries the next time it becomes active. Lives in Shared/ (compiled into the app,
/// widget, and share targets) to match the QuickAddIntent convention.
struct MoodCheckInIntent: AppIntent {
    static var title: LocalizedStringResource = "记录心情"
    static var description = IntentDescription("在小组件上快速记录当下的心情。")
    /// Silent — do not bring the app to the foreground.
    static var openAppWhenRun: Bool = false

    @Parameter(title: "心情")
    var mood: String

    init() {}
    init(mood: String) { self.mood = mood }

    func perform() async throws -> some IntentResult {
        MoodInbox.write(mood: mood)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
