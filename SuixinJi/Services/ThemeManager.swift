import SwiftUI
import Combine

/// User-selectable appearance (evolution): accent color + font-size scale.
/// Persisted in UserDefaults; drives `.tint` and `\.themeScale` at each root.
@MainActor
final class ThemeManager: ObservableObject {
    @Published var accent: AccentOption {
        didSet { UserDefaults.standard.set(accent.rawValue, forKey: accentKey) }
    }
    @Published var fontScale: FontScaleOption {
        didSet { UserDefaults.standard.set(fontScale.rawValue, forKey: scaleKey) }
    }

    private let accentKey = "themeAccent"
    private let scaleKey = "themeFontScale"

    init() {
        accent = AccentOption(rawValue: UserDefaults.standard.string(forKey: accentKey) ?? "") ?? .orange
        fontScale = FontScaleOption(rawValue: UserDefaults.standard.string(forKey: scaleKey) ?? "") ?? .standard
    }

    /// Accent presets. `orange` (#FF8A5C) is the default and matches the app icon.
    enum AccentOption: String, CaseIterable, Identifiable {
        case orange, indigo, green, rose, graphite
        var id: String { rawValue }

        var name: String {
            switch self {
            case .orange: return "暖橙"
            case .indigo: return "靛蓝"
            case .green: return "森绿"
            case .rose: return "玫红"
            case .graphite: return "石墨"
            }
        }
        var color: Color {
            switch self {
            case .orange: return Color(red: 255/255, green: 138/255, blue: 92/255)   // #FF8A5C
            case .indigo: return Color(red: 88/255, green: 86/255, blue: 214/255)     // systemIndigo-ish
            case .green: return Color(red: 52/255, green: 168/255, blue: 118/255)
            case .rose: return Color(red: 226/255, green: 90/255, blue: 130/255)
            case .graphite: return Color(red: 110/255, green: 110/255, blue: 118/255)
            }
        }
    }

    /// Font-size scale relative to the base type ramp.
    enum FontScaleOption: String, CaseIterable, Identifiable {
        case small, standard, large, xlarge
        var id: String { rawValue }

        var name: String {
            switch self {
            case .small: return "小"
            case .standard: return "标准"
            case .large: return "大"
            case .xlarge: return "特大"
            }
        }
        var value: CGFloat {
            switch self {
            case .small: return 0.9
            case .standard: return 1.0
            case .large: return 1.15
            case .xlarge: return 1.3
            }
        }
    }
}

/// Apply the current theme (tint + font scale) to a screen root. Needed on each
/// sheet-presented root because `.tint` / custom environment values don't
/// reliably cross sheet boundaries (the ThemeManager object does).
private struct ThemedRoot: ViewModifier {
    @EnvironmentObject private var theme: ThemeManager
    func body(content: Content) -> some View {
        content
            .tint(theme.accent.color)
            .environment(\.themeScale, theme.fontScale.value)
    }
}

extension View {
    func themedRoot() -> some View { modifier(ThemedRoot()) }
}
