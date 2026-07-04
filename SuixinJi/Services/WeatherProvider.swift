import Foundation
import WeatherKit
import CoreLocation
import Combine

/// Real current weather via Apple **WeatherKit** (F14). Returns an emoji + a
/// short "晴 26°" string for a coordinate. WeatherKit needs the WeatherKit
/// capability + a paid account; without it the call throws and the UI falls
/// back to the manual emoji picker (no crash, no compile flag needed).
@MainActor
final class WeatherProvider: ObservableObject {
    struct Reading: Equatable {
        var emoji: String
        var text: String   // e.g. "晴 26°"
    }

    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    func fetch(latitude: Double, longitude: Double) async -> Reading? {
        isLoading = true
        defer { isLoading = false }
        let location = CLLocation(latitude: latitude, longitude: longitude)
        do {
            let current = try await WeatherService.shared.weather(for: location).currentWeather
            let celsius = current.temperature.converted(to: .celsius).value
            let (emoji, name) = WeatherProvider.describe(current.condition)
            return Reading(emoji: emoji, text: "\(name) \(Int(celsius.rounded()))°")
        } catch {
            errorMessage = "天气获取失败，请手动选择。"
            return nil
        }
    }

    /// Map a WeatherKit condition to (emoji, 中文名). Pure — unit-tested.
    nonisolated static func describe(_ condition: WeatherCondition) -> (emoji: String, name: String) {
        switch condition {
        case .clear, .mostlyClear, .hot:
            return ("☀️", "晴")
        case .partlyCloudy:
            return ("🌤️", "多云")
        case .cloudy, .mostlyCloudy:
            return ("☁️", "阴")
        case .foggy, .haze, .smoky:
            return ("🌫️", "雾")
        case .drizzle, .rain, .sunShowers, .heavyRain:
            return ("🌧️", "雨")
        case .isolatedThunderstorms, .scatteredThunderstorms, .strongStorms, .thunderstorms:
            return ("⛈️", "雷雨")
        case .snow, .heavySnow, .flurries, .sleet, .wintryMix, .blizzard,
             .freezingDrizzle, .freezingRain, .frigid, .hail:
            return ("❄️", "雪")
        case .windy, .breezy, .blowingDust, .tropicalStorm, .hurricane:
            return ("🌬️", "风")
        default:
            return ("🌤️", "多云")
        }
    }
}
