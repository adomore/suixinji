import XCTest
@testable import SuixinJi

/// Apple Health · State of Mind (evolution). The mood→valence mapping is pure and
/// HealthKit-free, so we can verify every catalog mood maps into the required range.
final class HealthServiceTests: XCTestCase {

    func testEveryCatalogMoodMaps() {
        for mood in DiaryCatalog.moods {
            XCTAssertNotNil(HealthService.valence(for: mood), "unmapped mood: \(mood)")
        }
    }

    func testValenceStaysInHealthKitRange() {
        for mood in DiaryCatalog.moods {
            guard let v = HealthService.valence(for: mood) else { continue }
            XCTAssertGreaterThanOrEqual(v, -1.0)
            XCTAssertLessThanOrEqual(v, 1.0)
        }
    }

    func testBrightAndDarkMoodsHaveExpectedSign() {
        XCTAssertEqual(HealthService.valence(for: "😊"), 1.0)     // 2 / 2
        XCTAssertEqual(HealthService.valence(for: "😢"), -1.0)    // -2 / 2
        XCTAssertEqual(HealthService.valence(for: "😐"), 0.0)     // neutral
        XCTAssertEqual(HealthService.valence(for: "🙂"), 0.5)     // 1 / 2
    }

    func testUnknownMoodIsNil() {
        XCTAssertNil(HealthService.valence(for: "🤖"))
        XCTAssertNil(HealthService.valence(for: ""))
    }
}
