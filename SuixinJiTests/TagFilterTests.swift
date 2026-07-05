import XCTest
import SwiftData
@testable import SuixinJi

/// 标签管理 + 组合筛选 engines (evolution).
@MainActor
final class TagFilterTests: XCTestCase {

    private func context() throws -> ModelContext {
        let c = try ModelContainer(for: DiaryEntry.self,
                                   configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        return ModelContext(c)
    }

    // MARK: DiaryFilter

    func testFilterInactivePassesThrough() {
        let e = [DiaryEntry(text: "a")]
        XCTAssertEqual(DiaryFilter().apply(to: e).count, 1)
        XCTAssertFalse(DiaryFilter().isActive)
    }

    func testFilterByMoodAnyOf() {
        let happy = DiaryEntry(text: "h", mood: "😊")
        let sad = DiaryEntry(text: "s", mood: "😢")
        let none = DiaryEntry(text: "n")
        var f = DiaryFilter(); f.moods = ["😊", "😢"]
        let out = f.apply(to: [happy, sad, none])
        XCTAssertEqual(Set(out.map(\.text)), ["h", "s"]) // none excluded
    }

    func testFilterByTagAnyOf() {
        let a = DiaryEntry(text: "a", tags: ["旅行", "美食"])
        let b = DiaryEntry(text: "b", tags: ["工作"])
        var f = DiaryFilter(); f.tags = ["旅行"]
        XCTAssertEqual(f.apply(to: [a, b]).map(\.text), ["a"])
    }

    func testFilterRequireMediaCombinesWithAND() {
        let photoHappy = DiaryEntry(text: "ph", mood: "😊", imageFileNames: ["x.jpg"])
        let happyNoPhoto = DiaryEntry(text: "np", mood: "😊")
        var f = DiaryFilter(); f.moods = ["😊"]; f.requirePhoto = true
        XCTAssertEqual(f.apply(to: [photoHappy, happyNoPhoto]).map(\.text), ["ph"])
    }

    func testActiveCount() {
        var f = DiaryFilter()
        f.moods = ["😊", "😐"]; f.tags = ["旅行"]; f.requireAudio = true
        XCTAssertEqual(f.activeCount, 4)
        XCTAssertTrue(f.isActive)
    }

    // MARK: TagManager pure transforms

    func testRenamingDeduplicatesWhenMerging() {
        // Entry already has both — renaming 美食→旅行 must not duplicate 旅行.
        XCTAssertEqual(TagManager.renaming(["旅行", "美食"], from: "美食", to: "旅行"), ["旅行"])
        XCTAssertEqual(TagManager.renaming(["美食", "工作"], from: "美食", to: "旅行"), ["旅行", "工作"])
        XCTAssertEqual(TagManager.renaming(["工作"], from: "美食", to: "旅行"), ["工作"]) // unchanged
    }

    func testRemoving() {
        XCTAssertEqual(TagManager.removing(["旅行", "美食"], tag: "美食"), ["旅行"])
    }

    func testTagCountsSorted() {
        let e = [DiaryEntry(text: "1", tags: ["旅行", "美食"]),
                 DiaryEntry(text: "2", tags: ["旅行"])]
        let counts = TagManager.tagCounts(e)
        XCTAssertEqual(counts.first, TagManager.TagCount(tag: "旅行", count: 2))
        XCTAssertEqual(counts.map(\.tag), ["旅行", "美食"])
    }

    // MARK: TagManager context mutators

    func testRenameAcrossEntriesAndMerge() throws {
        let ctx = try context()
        let a = DiaryEntry(text: "a", tags: ["美食"])
        let b = DiaryEntry(text: "b", tags: ["旅行", "美食"]) // will merge to just 旅行
        ctx.insert(a); ctx.insert(b); try ctx.save()

        let changed = TagManager.rename(from: "美食", to: "旅行", in: [a, b], context: ctx)
        XCTAssertEqual(changed, 2)
        XCTAssertEqual(a.tags, ["旅行"])
        XCTAssertEqual(b.tags, ["旅行"]) // deduped
    }

    func testRenameRejectsEmptyOrSame() throws {
        let ctx = try context()
        let a = DiaryEntry(text: "a", tags: ["美食"])
        ctx.insert(a); try ctx.save()
        XCTAssertEqual(TagManager.rename(from: "美食", to: "   ", in: [a], context: ctx), 0)
        XCTAssertEqual(TagManager.rename(from: "美食", to: "美食", in: [a], context: ctx), 0)
        XCTAssertEqual(a.tags, ["美食"])
    }

    func testDeleteTagAcrossEntries() throws {
        let ctx = try context()
        let a = DiaryEntry(text: "a", tags: ["美食", "旅行"])
        let b = DiaryEntry(text: "b", tags: ["工作"])
        ctx.insert(a); ctx.insert(b); try ctx.save()
        let changed = TagManager.delete(tag: "美食", in: [a, b], context: ctx)
        XCTAssertEqual(changed, 1)
        XCTAssertEqual(a.tags, ["旅行"])
        XCTAssertEqual(b.tags, ["工作"])
    }
}
