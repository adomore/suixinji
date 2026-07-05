import SwiftUI

// MARK: - Colors
//
// Per the UI Brief §3.3 we lean on iOS *semantic* colors so dark mode is free;
// the warm-orange accent `#FF8A5C` is used only as an accent (FAB, save button,
// waveform, recording state) — never as a large fill.

extension Color {
    /// Accent 暖橙 `#FF8A5C`. Also mirrored in `Assets.xcassets/AccentColor`.
    static let brand = Color(red: 255 / 255, green: 138 / 255, blue: 92 / 255)

    // Semantic wrappers (map straight onto UIKit system colors → auto light/dark).
    static let pageBackground = Color(uiColor: .systemBackground)
    static let cardBackground = Color(uiColor: .secondarySystemBackground)
    static let groupedBackground = Color(uiColor: .systemGroupedBackground)
    static let tertiaryFill = Color(uiColor: .tertiaryLabel)
}

// MARK: - Layout tokens (UI Brief §3.4)

enum Layout {
    static let pageMargin: CGFloat = 16
    static let cardRadius: CGFloat = 16
    static let cardGap: CGFloat = 12
    static let cardPadding: CGFloat = 16
    static let fabDiameter: CGFloat = 56
    static let fabTrailing: CGFloat = 16
    static let fabBottom: CGFloat = 24
    static let thumbnail: CGFloat = 60          // timeline card thumbnails
    static let gridThumbnail: CGFloat = 80       // editor nine-grid cells
    static let thumbnailRadius: CGFloat = 8
    static let maxImages = 9
    static let maxThumbsOnCard = 3
    static let maxRecordSeconds: TimeInterval = 600  // 10-minute cap (F3)
}

// MARK: - Type ramp (UI Brief §3.2) — scalable via the theme font-size setting
//
// System font only (SF Pro / PingFang). Base sizes match the mockups; the theme
// applies a global multiplier through `\.themeScale`, so all `.scaledFont(size)`
// text grows/shrinks together. `ImageRenderer` exports don't inherit the root
// environment, so shared cards/PDFs always render at the base (×1) size.

/// Global font-size multiplier injected by the theme at the app root.
private struct ThemeScaleKey: EnvironmentKey { static let defaultValue: CGFloat = 1.0 }
extension EnvironmentValues {
    var themeScale: CGFloat {
        get { self[ThemeScaleKey.self] }
        set { self[ThemeScaleKey.self] = newValue }
    }
}

private struct ScaledFontModifier: ViewModifier {
    let size: CGFloat
    let weight: Font.Weight
    @Environment(\.themeScale) private var scale
    func body(content: Content) -> some View {
        // NB: must call the real SwiftUI font here — calling scaledFont would
        // recurse forever (the migration script clobbered this once).
        content.font(.system(size: size * scale, weight: weight))
    }
}

extension View {
    /// System font at `size` × the current theme scale. Replaces the old fixed
    /// `.font(.system(size:))` / type-ramp constants.
    func scaledFont(_ size: CGFloat, weight: Font.Weight = .regular) -> some View {
        modifier(ScaledFontModifier(size: size, weight: weight))
    }
}

// MARK: - Date formatting helpers (real Chinese copy — no placeholders)

enum DiaryDateFormat {
    /// Locale-aware (evolution · localization): Chinese keeps the exact original
    /// patterns (so nothing changes for zh users / tests); other languages use
    /// locale-appropriate templates, e.g. English "Sat, Jul 4".
    private static func isChinese(_ locale: Locale) -> Bool {
        locale.language.languageCode == .chinese
    }

    /// zh "7月4日 星期六" · en "Sat, Jul 4"
    static func longChinese(_ date: Date, locale: Locale = .current) -> String {
        let f = DateFormatter(); f.locale = locale
        if isChinese(locale) { f.dateFormat = "M月d日 EEEE" }
        else { f.setLocalizedDateFormatFromTemplate("EEEMMMd") }
        return f.string(from: date)
    }

    /// zh "7月4日" · en "Jul 4"
    static func shortChinese(_ date: Date, locale: Locale = .current) -> String {
        let f = DateFormatter(); f.locale = locale
        if isChinese(locale) { f.dateFormat = "M月d日" }
        else { f.setLocalizedDateFormatFromTemplate("MMMd") }
        return f.string(from: date)
    }

    /// zh "4日" · en "4"
    static func dayNumber(_ date: Date, locale: Locale = .current) -> String {
        let f = DateFormatter(); f.locale = locale
        f.dateFormat = isChinese(locale) ? "d日" : "d"
        return f.string(from: date)
    }

    /// zh "周六" · en "Sat" (locale localizes the weekday either way)
    static func weekdayShort(_ date: Date, locale: Locale = .current) -> String {
        let f = DateFormatter(); f.locale = locale
        f.dateFormat = "EEE"
        return f.string(from: date)
    }

    /// zh "2026年7月" · en "Jul 2026" — year-month section headers.
    static func yearMonth(_ date: Date, locale: Locale = .current) -> String {
        let f = DateFormatter(); f.locale = locale
        if isChinese(locale) { f.dateFormat = "yyyy年M月" }
        else { f.setLocalizedDateFormatFromTemplate("yMMM") }
        return f.string(from: date)
    }

    /// mm:ss, e.g. "0:35" (single-digit minutes) — matches the card badge.
    static func duration(_ seconds: TimeInterval, padMinutes: Bool = false) -> String {
        let total = Int(seconds.rounded())
        let m = total / 60
        let s = total % 60
        return padMinutes
            ? String(format: "%02d:%02d", m, s)
            : String(format: "%d:%02d", m, s)
    }
}
