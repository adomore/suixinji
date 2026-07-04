import Foundation
import LocalAuthentication
import Combine

/// Face ID / Touch ID / passcode gate (F12). When the user enables the lock in
/// Settings, the app content is covered until `authenticate()` succeeds — on
/// launch and whenever it returns from the background.
@MainActor
final class AppLockManager: ObservableObject {
    private let key = "appLockEnabled"

    /// True when the app is locked and content must be hidden.
    @Published var isLocked: Bool

    /// Mirrors the Settings toggle (persisted in UserDefaults).
    @Published var enabled: Bool {
        didSet { UserDefaults.standard.set(enabled, forKey: key) }
    }

    init() {
        let on = UserDefaults.standard.bool(forKey: key)
        enabled = on
        isLocked = on
    }

    /// Whether the device can do biometric / passcode auth at all.
    var isAvailable: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

    /// Re-lock when leaving the foreground (called on scenePhase change).
    func lockIfEnabled() {
        if enabled { isLocked = true }
    }

    /// Prompt for Face ID / Touch ID, falling back to the device passcode.
    func authenticate() async {
        guard enabled else { isLocked = false; return }
        let context = LAContext()
        context.localizedFallbackTitle = "输入密码"
        do {
            let ok = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "解锁随心记，查看你的日记。"
            )
            isLocked = !ok
        } catch {
            isLocked = true // stay locked on cancel / failure
        }
    }
}
