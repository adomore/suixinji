import XCTest
@testable import SuixinJi

/// The widget's shared snapshot (evolution). The app writes it; the widget reads
/// it. Only the pure Codable round-trip is unit-tested — the App Group container
/// I/O is exercised on device.
final class WidgetSnapshotTests: XCTestCase {
    func testCodableRoundTrip() throws {
        let snap = WidgetSnapshot(currentStreak: 5, totalEntries: 20,
                                  wroteToday: true, generatedAt: Date(timeIntervalSince1970: 1_000))
        let data = try JSONEncoder().encode(snap)
        let decoded = try JSONDecoder().decode(WidgetSnapshot.self, from: data)
        XCTAssertEqual(decoded, snap)
    }

    func testEmptyDefaults() {
        XCTAssertEqual(WidgetSnapshot.empty.currentStreak, 0)
        XCTAssertEqual(WidgetSnapshot.empty.totalEntries, 0)
        XCTAssertFalse(WidgetSnapshot.empty.wroteToday)
    }
}
