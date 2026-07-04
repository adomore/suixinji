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

// MARK: - Type ramp (UI Brief §3.2)
//
// System font only (SF Pro / PingFang). Sizes are fixed to match the mockups.

extension Font {
    static let largeTitle34 = Font.system(size: 34, weight: .bold)
    static let cardDate22 = Font.system(size: 22, weight: .semibold)
    static let body17 = Font.system(size: 17, weight: .regular)
    static let navTitle17 = Font.system(size: 17, weight: .semibold)
    static let summary15 = Font.system(size: 15, weight: .regular)
    static let aux13 = Font.system(size: 13, weight: .regular)
    static let groupHeader13 = Font.system(size: 13, weight: .medium)
    static let label11 = Font.system(size: 11, weight: .regular)
}

// MARK: - Date formatting helpers (real Chinese copy — no placeholders)

enum DiaryDateFormat {
    /// "7月4日 星期六"
    static func longChinese(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日 EEEE"
        return f.string(from: date)
    }

    /// "7月4日"
    static func shortChinese(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日"
        return f.string(from: date)
    }

    /// "4日"
    static func dayNumber(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "d日"
        return f.string(from: date)
    }

    /// "周六"
    static func weekdayShort(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "EEE"
        return f.string(from: date)
    }

    /// "2026年7月" — used for the year-month section headers.
    static func yearMonth(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy年M月"
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
