import SwiftUI
import SwiftData
import CoreSpotlight
import UserNotifications

@main
struct SuixinJiApp: App {
    init() {
        // UI-test hygiene: clear any pending/delivered notifications (e.g. a daily
        // reminder scheduled during manual testing) so their system banners can't
        // interrupt automation. No effect on normal launches.
        if ProcessInfo.processInfo.arguments.contains("-uitest") {
            let center = UNUserNotificationCenter.current()
            center.removeAllPendingNotificationRequests()
            center.removeAllDeliveredNotifications()
        }
    }

    /// Single SwiftData container (PRD §5.1). iCloud sync (F11) is on by default
    /// with a graceful local fallback; UI tests use an in-memory store. See
    /// `Persistence`.
    let container: ModelContainer = {
        let uiTesting = ProcessInfo.processInfo.arguments.contains("-uitest")
        let container = Persistence.container(inMemory: uiTesting)
        #if DEBUG
        // UI-test seam: seed one entry dated exactly a year ago (same month/day)
        // so the "这一天" memories banner has something to show.
        if ProcessInfo.processInfo.arguments.contains("-uitest-seed-memory"),
           let lastYear = Calendar(identifier: .gregorian).date(byAdding: .year, value: -1, to: Date()) {
            container.mainContext.insert(DiaryEntry(diaryDate: lastYear, text: "去年今天的回忆"))
            try? container.mainContext.save()
        }
        // Seed one private entry so a UI test can assert it renders redacted (私密日记).
        if ProcessInfo.processInfo.arguments.contains("-uitest-seed-private") {
            container.mainContext.insert(DiaryEntry(text: "私密内容不该出现", isPrivate: true))
            try? container.mainContext.save()
        }
        #endif
        return container
    }()

    @StateObject private var lock = AppLockManager()
    @StateObject private var theme = ThemeManager()
    @StateObject private var router = AppRouter()
    @StateObject private var privacy = PrivacyManager()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            HomeView()
                .overlay { if lock.isLocked { LockScreen() } }
                .task { await lock.authenticate() } // prompt on cold launch
                .task { reconcileMedia() }          // F11: materialize/upload media
                .onChange(of: scenePhase) { _, phase in
                    switch phase {
                    case .background:
                        lock.lockIfEnabled()
                        privacy.conceal() // re-hide 私密日记 when leaving the foreground
                    case .active:
                        if lock.isLocked { Task { await lock.authenticate() } }
                        reconcileMedia() // pick up media that synced while away
                        ShareImporter.importPending(into: container.mainContext) // drain shared items
                        MoodCheckInImporter.importPending(into: container.mainContext) // drain widget mood check-ins

                    default: break
                    }
                }
                // Spotlight deep link: tapping a diary in system search opens it.
                .onContinueUserActivity(CSSearchableItemActionType) { router.handle($0) }
                // themedRoot applies tint + scale and READS ThemeManager from the
                // environment, so the environmentObjects must wrap it (be applied
                // outside/after) — otherwise ThemedRoot resolves against WindowGroup
                // where nothing was injected and crashes. As the outermost modifiers
                // the objects still propagate down into HomeView, its sheets, and the
                // lock overlay.
                .themedRoot()
                .environmentObject(lock)
                .environmentObject(theme)
                .environmentObject(router)
                .environmentObject(privacy)
        }
        .modelContainer(container)
    }

    /// Reconcile synced media blobs ⇄ local files (F11). Runs on the main context;
    /// a personal diary's media set is small, and it skips quickly when there's
    /// nothing new to move.
    @MainActor
    private func reconcileMedia() {
        MediaSyncService.reconcile(context: container.mainContext)
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
