import XCTest
import WeatherKit
@testable import SuixinJi

/// WeatherKit condition → (emoji, 中文名) mapping (F14). Pure, no network.
final class WeatherMappingTests: XCTestCase {
    func testClearMapsToSun() {
        XCTAssertEqual(WeatherProvider.describe(.clear).emoji, "☀️")
        XCTAssertEqual(WeatherProvider.describe(.clear).name, "晴")
    }

    func testRainAndSnow() {
        XCTAssertEqual(WeatherProvider.describe(.rain).emoji, "🌧️")
        XCTAssertEqual(WeatherProvider.describe(.heavySnow).emoji, "❄️")
    }

    func testCloudyAndFog() {
        XCTAssertEqual(WeatherProvider.describe(.cloudy).emoji, "☁️")
        XCTAssertEqual(WeatherProvider.describe(.foggy).emoji, "🌫️")
    }

    func testEmojiIsAlwaysFromTheWeatherPalette() {
        // Every mapped emoji should be one the manual picker also offers, so the
        // card/detail rendering stays consistent.
        let palette = Set(DiaryCatalog.weathers)
        for c in [WeatherCondition.clear, .partlyCloudy, .cloudy, .foggy, .rain,
                  .snow, .windy, .hot, .thunderstorms] {
            XCTAssertTrue(palette.contains(WeatherProvider.describe(c).emoji),
                          "\(c) → \(WeatherProvider.describe(c).emoji) not in palette")
        }
    }
}

/// Export smoke tests (F13): rendering produces real files. Runs on the main
/// actor because ImageRenderer is main-actor bound.
@MainActor
final class DiaryExporterTests: XCTestCase {

    private func sampleEntry() -> DiaryEntry {
        DiaryEntry(
            text: String(repeating: "今天去看了朝霞，云层烧得特别透。", count: 60), // long → multi-page
            mood: "😊", weather: "☀️", weatherText: "晴 26°",
            tags: ["旅行"], locationName: "杭州市西湖区"
        )
    }

    func testExportLongImageProducesPNG() throws {
        let url = try XCTUnwrap(DiaryExporter.exportLongImage(sampleEntry()))
        XCTAssertEqual(url.pathExtension, "png")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        let data = try Data(contentsOf: url)
        XCTAssertGreaterThan(data.count, 0)
        try? FileManager.default.removeItem(at: url)
    }

    func testExportPDFProducesNonEmptyFile() throws {
        let url = try XCTUnwrap(DiaryExporter.exportPDF(sampleEntry()))
        XCTAssertEqual(url.pathExtension, "pdf")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        let data = try Data(contentsOf: url)
        XCTAssertGreaterThan(data.count, 0)
        // A PDF starts with "%PDF".
        XCTAssertEqual(data.prefix(4), Data("%PDF".utf8))
        try? FileManager.default.removeItem(at: url)
    }

    func testExportRecapProducesPNG() throws {
        let recap = MonthlyRecap(monthKey: "2026年7月", entryCount: 12, daysWritten: 8,
                                 topMood: "😊", withPhotos: 3, withAudio: 2)
        let url = try XCTUnwrap(DiaryExporter.exportRecap(recap))
        XCTAssertEqual(url.pathExtension, "png")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        XCTAssertGreaterThan(try Data(contentsOf: url).count, 0)
        try? FileManager.default.removeItem(at: url)
    }
}
