import XCTest
import SwiftData
@testable import SuixinJi

/// Pure-function tests for the P1/P2 additions: search (F8), reminder parsing
/// (F10), and the mood/weather catalog (F7/F14).
final class MetadataTests: XCTestCase {

    // MARK: Search (F8)

    private func makeEntry(text: String = "", tags: [String] = [],
                           mood: String? = nil, location: String? = nil) -> DiaryEntry {
        DiaryEntry(text: text, mood: mood, tags: tags, locationName: location)
    }

    func testSearchEmptyQueryReturnsAll() {
        let entries = [makeEntry(text: "a"), makeEntry(text: "b")]
        XCTAssertEqual(DiarySearch.filter(entries, query: "").count, 2)
        XCTAssertEqual(DiarySearch.filter(entries, query: "   ").count, 2)
    }

    func testSearchMatchesText() {
        let entries = [makeEntry(text: "今天去看了朝霞"), makeEntry(text: "加班到很晚")]
        let hits = DiarySearch.filter(entries, query: "朝霞")
        XCTAssertEqual(hits.count, 1)
        XCTAssertEqual(hits.first?.text, "今天去看了朝霞")
    }

    func testSearchMatchesTagCaseInsensitive() {
        let entries = [makeEntry(text: "x", tags: ["Travel"]), makeEntry(text: "y", tags: ["work"])]
        XCTAssertEqual(DiarySearch.filter(entries, query: "travel").count, 1)
    }

    func testSearchMatchesLocationAndMood() {
        let entries = [
            makeEntry(text: "1", mood: "😊", location: "杭州市西湖区"),
            makeEntry(text: "2"),
        ]
        XCTAssertEqual(DiarySearch.filter(entries, query: "西湖").count, 1)
        XCTAssertEqual(DiarySearch.filter(entries, query: "😊").count, 1)
    }

    func testSearchNoMatch() {
        let entries = [makeEntry(text: "abc")]
        XCTAssertTrue(DiarySearch.filter(entries, query: "zzz").isEmpty)
    }

    // MARK: Reminder time parsing (F10)

    private func assertParse(_ input: String, _ h: Int, _ m: Int,
                             file: StaticString = #filePath, line: UInt = #line) {
        let r = ReminderManager.parse(input)
        XCTAssertEqual(r.hour, h, file: file, line: line)
        XCTAssertEqual(r.minute, m, file: file, line: line)
    }

    func testReminderParseValid() {
        assertParse("21:00", 21, 0)
        assertParse("07:05", 7, 5)
    }

    func testReminderParseInvalidFallsBackTo2100() {
        assertParse("garbage", 21, 0)
        assertParse("", 21, 0)
    }

    func testReminderParseClampsOutOfRange() {
        assertParse("99:99", 23, 59)
    }

    // MARK: Catalog (F7 / F14)

    func testCatalogHasDistinctEmojis() {
        XCTAssertFalse(DiaryCatalog.moods.isEmpty)
        XCTAssertFalse(DiaryCatalog.weathers.isEmpty)
        XCTAssertEqual(Set(DiaryCatalog.moods).count, DiaryCatalog.moods.count)
        XCTAssertEqual(Set(DiaryCatalog.weathers).count, DiaryCatalog.weathers.count)
    }
}

/// Metadata persistence through DiaryService (F7/F14).
@MainActor
final class MetadataPersistenceTests: XCTestCase {
    private var context: ModelContext!
    private var root: URL!
    private var store: FileStoreImpl!

    override func setUpWithError() throws {
        let container = try ModelContainer(
            for: DiaryEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        context = ModelContext(container)
        root = FileManager.default.temporaryDirectory.appendingPathComponent("meta-\(UUID().uuidString)")
        store = FileStoreImpl(root: root)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    func testMetadataIsPersisted() throws {
        let draft = DiaryDraft(
            text: "配元数据", mood: "😊", weather: "☀️",
            tags: ["旅行", "朝霞"], locationName: "杭州市西湖区",
            latitude: 30.2, longitude: 120.1
        )
        let saved = try DiaryService.save(draft, existing: nil, into: context, fileStore: store)
        XCTAssertEqual(saved.mood, "😊")
        XCTAssertEqual(saved.weather, "☀️")
        XCTAssertEqual(saved.tags, ["旅行", "朝霞"])
        XCTAssertEqual(saved.locationName, "杭州市西湖区")
        XCTAssertEqual(saved.latitude ?? 0, 30.2, accuracy: 0.0001)
    }

    func testEditingCanClearMetadata() throws {
        let created = try DiaryService.save(
            DiaryDraft(text: "x", mood: "😊", tags: ["a"]),
            existing: nil, into: context, fileStore: store)
        _ = try DiaryService.save(
            DiaryDraft(text: "x", mood: nil, tags: []),
            existing: created, into: context, fileStore: store)
        XCTAssertNil(created.mood)
        XCTAssertTrue(created.tags.isEmpty)
    }
}
