import XCTest
@testable import SuixinJi

/// Theme skin (evolution): accent + font-scale options and their persistence.
@MainActor
final class ThemeManagerTests: XCTestCase {
    private let accentKey = "themeAccent"
    private let scaleKey = "themeFontScale"

    override func setUp() {
        UserDefaults.standard.removeObject(forKey: accentKey)
        UserDefaults.standard.removeObject(forKey: scaleKey)
    }
    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: accentKey)
        UserDefaults.standard.removeObject(forKey: scaleKey)
    }

    func testDefaults() {
        let t = ThemeManager()
        XCTAssertEqual(t.accent, .orange)
        XCTAssertEqual(t.fontScale, .standard)
    }

    func testAccentPersistsAcrossInstances() {
        let t = ThemeManager()
        t.accent = .indigo
        XCTAssertEqual(ThemeManager().accent, .indigo) // a fresh manager reads it back
    }

    func testFontScalePersistsAcrossInstances() {
        let t = ThemeManager()
        t.fontScale = .large
        XCTAssertEqual(ThemeManager().fontScale, .large)
    }

    func testFontScaleValues() {
        XCTAssertEqual(ThemeManager.FontScaleOption.small.value, 0.9, accuracy: 0.0001)
        XCTAssertEqual(ThemeManager.FontScaleOption.standard.value, 1.0, accuracy: 0.0001)
        XCTAssertEqual(ThemeManager.FontScaleOption.large.value, 1.15, accuracy: 0.0001)
        XCTAssertEqual(ThemeManager.FontScaleOption.xlarge.value, 1.3, accuracy: 0.0001)
    }

    func testAccentOptionsAreDistinctAndNamed() {
        let opts = ThemeManager.AccentOption.allCases
        XCTAssertEqual(opts.count, 5)
        XCTAssertEqual(Set(opts.map(\.rawValue)).count, 5)
        XCTAssertTrue(opts.allSatisfy { !$0.name.isEmpty })
    }

    func testUnknownStoredValueFallsBackToDefault() {
        UserDefaults.standard.set("nonsense", forKey: accentKey)
        XCTAssertEqual(ThemeManager().accent, .orange)
    }
}
