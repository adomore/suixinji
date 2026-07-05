import AppIntents

/// Exposes the app's intents to Siri & Spotlight as ready-made **App Shortcuts**
/// (evolution). These give spoken phrases with zero setup — the user can just say
/// "用随心记记一笔" or find the action in Spotlight/Shortcuts. `QuickAddIntent`
/// lives in `Shared/` and is compiled into the app target.
struct SuixinJiShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: QuickAddIntent(),
            phrases: [
                "用\(.applicationName)记一笔",
                "在\(.applicationName)写日记",
                "打开\(.applicationName)记录"
            ],
            shortTitle: "写新日记",
            systemImageName: "square.and.pencil"
        )
    }
}
