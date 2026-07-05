import XCTest
import SwiftData
@testable import SuixinJi

/// 快速心情打卡 (evolution). The widget writes a check-in to the App Group inbox; the
/// app drains it. Tests cover the pure "update or create" decision and the DTO codec
/// (App-Group I/O itself is environment-dependent and exercised on device).
final class MoodCheckInTests: XCTestCase {

    private var calendar = Calendar(identifier: .gregorian)
    private let today = Date()

    func testPendingMoodCodableRoundTrip() throws {
        let m = MoodInbox.PendingMood(id: "abc", mood: "😊", date: Date(timeIntervalSince1970: 1000))
        let data = try JSONEncoder().encode(m)
        let back = try JSONDecoder().decode(MoodInbox.PendingMood.self, from: data)
        XCTAssertEqual(m, back)
    }

    func testUpdatableCheckInFindsMoodOnlyTodayEntry() {
        let checkIn = DiaryEntry(diaryDate: today, mood: "🙂")           // empty text, no media
        let entries = [DiaryEntry(diaryDate: today, text: "写了很多"), checkIn]
        let found = MoodCheckInImporter.updatableCheckIn(in: entries, on: today, calendar: calendar)
        XCTAssertEqual(found?.id, checkIn.id)
    }

    func testUpdatableCheckInIgnoresEntryWithText() {
        let entries = [DiaryEntry(diaryDate: today, text: "今天很充实", mood: "😊")]
        XCTAssertNil(MoodCheckInImporter.updatableCheckIn(in: entries, on: today, calendar: calendar))
    }

    func testUpdatableCheckInIgnoresEntryWithMedia() {
        let withPhoto = DiaryEntry(diaryDate: today, imageFileNames: ["a.jpg"])
        XCTAssertNil(MoodCheckInImporter.updatableCheckIn(in: [withPhoto], on: today, calendar: calendar))
    }

    func testUpdatableCheckInIgnoresOtherDays() {
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let old = DiaryEntry(diaryDate: yesterday, mood: "😴")
        XCTAssertNil(MoodCheckInImporter.updatableCheckIn(in: [old], on: today, calendar: calendar))
    }

    func testUpdatableCheckInNilWhenEmpty() {
        XCTAssertNil(MoodCheckInImporter.updatableCheckIn(in: [], on: today, calendar: calendar))
    }

    /// End-to-end of the "create then update" behaviour, simulating the importer's two
    /// branches against an in-memory store (without the App Group inbox).
    func testCreateThenUpdateInPlace() throws {
        let ctx = ModelContext(try ModelContainer(for: DiaryEntry.self,
                                                  configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
        // First check-in → no updatable entry → create.
        XCTAssertNil(MoodCheckInImporter.updatableCheckIn(
            in: try ctx.fetch(FetchDescriptor<DiaryEntry>()), on: today, calendar: calendar))
        ctx.insert(DiaryEntry(diaryDate: today, mood: "😐"))
        try ctx.save()

        // Second check-in → finds the bare entry → update its mood, no new row.
        let existing = try XCTUnwrap(MoodCheckInImporter.updatableCheckIn(
            in: try ctx.fetch(FetchDescriptor<DiaryEntry>()), on: today, calendar: calendar))
        existing.mood = "😊"
        try ctx.save()

        let all = try ctx.fetch(FetchDescriptor<DiaryEntry>())
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.mood, "😊")
    }
}
