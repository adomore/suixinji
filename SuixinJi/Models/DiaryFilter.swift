import Foundation

/// 组合筛选 (evolution). A composable filter over the timeline: any-of moods,
/// any-of tags, and require-photo / require-audio. Categories combine with AND;
/// within a category the match is OR. Pure & testable; composes with `DiarySearch`.
struct DiaryFilter: Equatable {
    var moods: Set<String> = []
    var tags: Set<String> = []
    var requirePhoto = false
    var requireAudio = false

    var isActive: Bool { !moods.isEmpty || !tags.isEmpty || requirePhoto || requireAudio }

    /// Number of active facets — for a badge on the filter button.
    var activeCount: Int {
        moods.count + tags.count + (requirePhoto ? 1 : 0) + (requireAudio ? 1 : 0)
    }

    func apply(to entries: [DiaryEntry]) -> [DiaryEntry] {
        guard isActive else { return entries }
        return entries.filter { e in
            if !moods.isEmpty {
                guard let m = e.mood, moods.contains(m) else { return false }
            }
            if !tags.isEmpty {
                guard e.tags.contains(where: { tags.contains($0) }) else { return false }
            }
            if requirePhoto && e.imageFileNames.isEmpty { return false }
            if requireAudio && e.audioFileName == nil { return false }
            return true
        }
    }
}
