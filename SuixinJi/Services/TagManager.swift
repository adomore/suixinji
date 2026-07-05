import Foundation
import SwiftData

/// 标签管理 (evolution). Rename / merge / delete tags across all entries. The
/// per-entry list transforms are pure (testable); the context mutators apply them
/// and save. Renaming a tag onto an existing one **merges** (dedup within an entry).
enum TagManager {
    struct TagCount: Identifiable, Equatable {
        var id: String { tag }
        let tag: String
        let count: Int
    }

    /// All tags with their usage counts, count desc then name asc.
    static func tagCounts(_ entries: [DiaryEntry]) -> [TagCount] {
        var map: [String: Int] = [:]
        for e in entries { for t in e.tags where !t.isEmpty { map[t, default: 0] += 1 } }
        return map
            .sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
            .map { TagCount(tag: $0.key, count: $0.value) }
    }

    // MARK: Pure per-entry transforms

    /// Replace `from` with `to` in one tag list, preserving order and de-duplicating
    /// (so merging onto an existing tag doesn't create a repeat).
    static func renaming(_ tags: [String], from: String, to: String) -> [String] {
        guard tags.contains(from) else { return tags }
        var result: [String] = []
        for t in tags {
            let mapped = (t == from) ? to : t
            if !result.contains(mapped) { result.append(mapped) }
        }
        return result
    }

    static func removing(_ tags: [String], tag: String) -> [String] {
        tags.filter { $0 != tag }
    }

    // MARK: Context mutators (best-effort save). Return the number of entries changed.

    @discardableResult
    static func rename(from: String, to rawTo: String, in entries: [DiaryEntry],
                       context: ModelContext) -> Int {
        let to = rawTo.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !to.isEmpty, to != from else { return 0 }
        var changed = 0
        for e in entries where e.tags.contains(from) {
            e.tags = renaming(e.tags, from: from, to: to)
            changed += 1
        }
        if changed > 0 { try? context.save() }
        return changed
    }

    @discardableResult
    static func delete(tag: String, in entries: [DiaryEntry], context: ModelContext) -> Int {
        var changed = 0
        for e in entries where e.tags.contains(tag) {
            e.tags = removing(e.tags, tag: tag)
            changed += 1
        }
        if changed > 0 { try? context.save() }
        return changed
    }
}
