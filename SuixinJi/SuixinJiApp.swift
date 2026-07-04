import SwiftUI
import SwiftData

@main
struct SuixinJiApp: App {
    /// Single SwiftData container for the one model in the app (PRD §5.1).
    let container: ModelContainer = {
        do {
            return try ModelContainer(for: DiaryEntry.self)
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
