import Foundation
#if canImport(HealthKit)
import HealthKit
#endif

/// Apple Health · 心情 → State of Mind (evolution).
/// When enabled, saving an entry with a mood logs a matching iOS 17 `HKStateOfMind`
/// sample to Health, so the diary's feelings show up alongside the user's mood data.
///
/// Write-only: the app never reads Health data. Permission-gated (Settings toggle),
/// and every call is a best-effort no-op if HealthKit is unavailable or unauthorized.
@MainActor
final class HealthService {
    static let shared = HealthService()

    /// Maps each catalog mood to a State-of-Mind valence in **[-1, 1]** and a label.
    /// Valence reuses `MoodTrends.valence` (a −2…2 scale) divided by 2.
    private static let labelForMood: [String: HealthMoodLabel] = [
        "😊": .happy, "🥳": .joyful, "🙂": .content, "😐": .indifferent,
        "😴": .drained, "😔": .disappointed, "😢": .sad, "😡": .angry
    ]

    /// Pure, testable: the State-of-Mind valence in **[-1, 1]** for a catalog mood,
    /// or nil if the mood isn't one we map. Reuses `MoodTrends.valence` (−2…2).
    nonisolated static func valence(for mood: String) -> Double? {
        guard labelForMood[mood] != nil, let raw = MoodTrends.valence[mood] else { return nil }
        return max(-1.0, min(1.0, raw / 2.0))
    }

    #if canImport(HealthKit)
    private let store = HKHealthStore()

    /// State of Mind is iOS 17+. Older systems: feature is simply off.
    var isSupported: Bool {
        if #available(iOS 17.0, *) { return HKHealthStore.isHealthDataAvailable() }
        return false
    }

    /// Ask the user to allow *writing* State of Mind. Returns whether we can proceed
    /// (true once the user has made a choice without error — HealthKit never reveals
    /// whether write access was actually granted, by design).
    @discardableResult
    func requestAuthorization() async -> Bool {
        guard isSupported, #available(iOS 17.0, *) else { return false }
        let type = HKObjectType.stateOfMindType()
        do {
            try await store.requestAuthorization(toShare: [type], read: [])
            return true
        } catch {
            return false
        }
    }

    /// Log a mood as a momentary-emotion State of Mind sample. Best-effort: silently
    /// returns if unsupported, unmapped, or the save fails (Health is a nice-to-have,
    /// never a reason to block or fail saving the diary itself).
    func logMood(_ mood: String, on date: Date) async {
        guard isSupported, #available(iOS 17.0, *),
              let label = Self.labelForMood[mood],
              let valence = Self.valence(for: mood) else { return }

        let sample = HKStateOfMind(
            date: date,
            kind: .momentaryEmotion,
            valence: valence,
            labels: [label.hkLabel],
            associations: []
        )
        try? await store.save(sample)
    }
    #else
    var isSupported: Bool { false }
    @discardableResult func requestAuthorization() async -> Bool { false }
    func logMood(_ mood: String, on date: Date) async {}
    #endif
}

/// Internal, HealthKit-free enum so the mood→label table above compiles even where
/// HealthKit is unavailable; resolved to a real `HKStateOfMind.Label` at call time.
private enum HealthMoodLabel {
    case happy, joyful, content, indifferent, drained, disappointed, sad, angry

    #if canImport(HealthKit)
    @available(iOS 17.0, *)
    var hkLabel: HKStateOfMind.Label {
        switch self {
        case .happy: return .happy
        case .joyful: return .joyful
        case .content: return .content
        case .indifferent: return .indifferent
        case .drained: return .drained
        case .disappointed: return .disappointed
        case .sad: return .sad
        case .angry: return .angry
        }
    }
    #endif
}
