import XCTest
@testable import SuixinJi

/// 传统节日 (evolution). Anchored on well-known 2025 dates; the `.chinese` calendar
/// is pinned to China time so day bucketing is stable regardless of host timezone.
final class FestivalTests: XCTestCase {

    private var gregorian: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return c
    }()
    private var chinese: Calendar = {
        var c = Calendar(identifier: .chinese)
        c.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return c
    }()

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        gregorian.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
    }

    private func festival(_ y: Int, _ m: Int, _ d: Int) -> String? {
        Festival.name(for: date(y, m, d), gregorian: gregorian, chinese: chinese)
    }

    func testLunarNewYearAndEve() {
        XCTAssertEqual(festival(2025, 1, 29), "春节")   // 正月初一
        XCTAssertEqual(festival(2025, 1, 28), "除夕")   // 春节前一天
    }

    func testLantern() {
        XCTAssertEqual(festival(2025, 2, 12), "元宵")   // 正月十五
    }

    func testDragonBoatAndMidAutumn() {
        XCTAssertEqual(festival(2025, 5, 31), "端午")   // 五月初五
        XCTAssertEqual(festival(2025, 10, 6), "中秋")   // 八月十五
    }

    func testSolarFestivals() {
        XCTAssertEqual(festival(2026, 1, 1), "元旦")
        XCTAssertEqual(festival(2026, 10, 1), "国庆")
        XCTAssertEqual(festival(2026, 12, 25), "圣诞")
    }

    func testOrdinaryDayHasNoFestival() {
        XCTAssertNil(festival(2025, 2, 5))   // 正月初八 — not a festival
    }

    func testAllNamesCoverAnchors() {
        for n in ["春节", "除夕", "元宵", "端午", "中秋", "国庆"] {
            XCTAssertTrue(Festival.allNames.contains(n), "missing \(n)")
        }
    }
}
