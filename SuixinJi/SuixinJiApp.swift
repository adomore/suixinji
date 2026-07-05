import SwiftUI
import SwiftData

@main
struct SuixinJiApp: App {
    /// Single SwiftData container for the one model in the app (PRD §5.1).
    /// - `-uitest` → fresh in-memory store (deterministic UI tests).
    /// - `CLOUDKIT_ENABLED` build flag → SwiftData + CloudKit sync (F11); requires
    ///   the iCloud capability + a paid account (see BUILD.md). Off by default so
    ///   a free-account local build keeps working unchanged.
    let container: ModelContainer = {
        let uiTesting = ProcessInfo.processInfo.arguments.contains("-uitest")
        let config: ModelConfiguration
        if uiTesting {
            config = ModelConfiguration(isStoredInMemoryOnly: true)
        } else {
            #if CLOUDKIT_ENABLED
            config = ModelConfiguration(cloudKitDatabase: .automatic)
            #else
            config = ModelConfiguration()
            #endif
        }
        do {
            let container = try ModelContainer(for: DiaryEntry.self, configurations: config)
            #if DEBUG
            // UI-test seam: seed one entry dated exactly a year ago (same month/day)
            // so the "这一天" memories banner has something to show.
            if ProcessInfo.processInfo.arguments.contains("-uitest-seed-memory"),
               let lastYear = Calendar(identifier: .gregorian).date(byAdding: .year, value: -1, to: Date()) {
                container.mainContext.insert(DiaryEntry(diaryDate: lastYear, text: "去年今天的回忆"))
                try? container.mainContext.save()
            }
            #endif
            return container
        } catch {
            fatalError("无法创建数据库容器: \(error)")
        }
    }()

    @StateObject private var lock = AppLockManager()
    @StateObject private var theme = ThemeManager()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            HomeView()
                .overlay { if lock.isLocked { LockScreen() } }
                .task { await lock.authenticate() } // prompt on cold launch
                .onChange(of: scenePhase) { _, phase in
                    switch phase {
                    case .background: lock.lockIfEnabled()
                    case .active: if lock.isLocked { Task { await lock.authenticate() } }
                    default: break
                    }
                }
                // Objects propagate into sheets; themedRoot applies tint + scale.
                .environmentObject(lock)
                .environmentObject(theme)
                .themedRoot()
        }
        .modelContainer(container)
    }
}

/// Opaque lock screen shown while the app is locked (F12). Hides diary content
/// behind biometrics/passcode.
private struct LockScreen: View {
    @EnvironmentObject private var lock: AppLockManager

    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground).ignoresSafeArea()
            VStack(spacing: 20) {
                Image(systemName: "lock.fill")
                    .scaledFont(44)
                    .foregroundStyle(Color.accentColor)
                Text("随心记已锁定").scaledFont(17, weight: .semibold)
                Button("解锁") { Task { await lock.authenticate() } }
                    .scaledFont(17)
                    .foregroundStyle(Color.accentColor)
            }
        }
    }
}
