import Foundation
import ActivityKit

/// Starts / updates / ends the 写作计时 Live Activity (evolution). Best-effort:
/// if Live Activities are off or a request fails, it silently no-ops so writing is
/// never blocked. Character-count updates are throttled to ~every 20 chars to stay
/// well under ActivityKit's update budget (the timer itself needs no updates).
@MainActor
final class WritingActivityController: ObservableObject {
    @Published private(set) var isActive = false

    private var activity: Activity<WritingActivityAttributes>?
    private var lastBucket = -1

    var isAvailable: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }

    func start(characters: Int) {
        guard isAvailable, activity == nil else { return }
        let attributes = WritingActivityAttributes(startDate: Date())
        let content = ActivityContent(state: WritingActivityAttributes.ContentState(characters: characters),
                                      staleDate: nil)
        do {
            activity = try Activity.request(attributes: attributes, content: content, pushType: nil)
            isActive = true
            lastBucket = characters / 20
        } catch {
            activity = nil
            isActive = false
        }
    }

    func update(characters: Int) {
        guard let activity else { return }
        let bucket = characters / 20
        guard bucket != lastBucket else { return } // throttle
        lastBucket = bucket
        let content = ActivityContent(state: WritingActivityAttributes.ContentState(characters: characters),
                                      staleDate: nil)
        Task { await activity.update(content) }
    }

    /// End the session (called on any editor dismissal). Safe to call when inactive.
    func end() {
        guard let activity else { return }
        self.activity = nil
        isActive = false
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
    }
}
