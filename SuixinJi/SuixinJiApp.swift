import SwiftUI
import SwiftData

@main
struct SuixinJiApp: App {
    /// Single SwiftData container for the one model in the app (PRD §5.1).
    /// UI tests launch with `-uitest` → a fresh in-memory store each run, so
    /// flows like the empty state and create/delete are deterministic.
    let container: ModelContainer = {
        let uiTesting = ProcessInfo.processInfo.arguments.contains("-uitest")
        let config = ModelConfiguration(isStoredInMemoryOnly: uiTesting)
        do {
            return try ModelContainer(for: DiaryEntry.self, configurations: config)
        } catch {
            fatalError("无法创建数据库容器: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .tint(.brand) // accent for buttons, etc. (never a large fill)
        }
        .modelContainer(container)
    }
}
