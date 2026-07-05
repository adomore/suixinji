import AppIntents

/// "写新日记" — opens the app to record. Exposed to Siri / Shortcuts and used by
/// the widget's compose button. Compiled into both targets.
struct QuickAddIntent: AppIntent {
    static var title: LocalizedStringResource = "写新日记"
    static var description = IntentDescription("打开随心记开始记录。")
    /// Bring the app to the foreground when run (from a widget tap or Shortcut).
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        .result()
    }
}
