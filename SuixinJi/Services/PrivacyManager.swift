import Foundation
import LocalAuthentication
import Combine

/// 私密日记 (evolution). A session-scoped gate for entries marked `isPrivate`.
/// Private entries are redacted in the timeline until the user authenticates with
/// Face ID / Touch ID / passcode; the reveal lasts until the app leaves the
/// foreground (mirrors `AppLockManager`), then re-hides.
@MainActor
final class PrivacyManager: ObservableObject {
    /// True while private entries should be shown in the clear.
    @Published private(set) var isRevealed = false

    /// Whether the device can authenticate at all (passcode / biometrics set).
    var canAuthenticate: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

    /// Prompt for Face ID / passcode to reveal private entries. No-op if already
    /// revealed. If the device has no passcode set (nothing to authenticate against),
    /// there's no protection to enforce, so reveal directly rather than trapping the
    /// user's own entries behind an unusable gate.
    func reveal() async {
        guard !isRevealed else { return }
        guard canAuthenticate else { isRevealed = true; return }
        let context = LAContext()
        context.localizedFallbackTitle = "输入密码"
        do {
            isRevealed = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "验证身份后查看私密日记。"
            )
        } catch {
            isRevealed = false // stay hidden on cancel / failure
        }
    }

    /// Re-hide private entries (called when the app leaves the foreground).
    func conceal() {
        isRevealed = false
    }

    /// Should this entry be shown redacted right now?
    func isHidden(_ entry: DiaryEntry) -> Bool {
        entry.isPrivate && !isRevealed
    }
}
