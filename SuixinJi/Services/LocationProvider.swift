import Foundation
import CoreLocation
import Combine

/// One-shot current-location capture + reverse geocoding to a place name (F14).
/// The user taps "位置" in the editor; we grab a single fix and turn it into a
/// human-readable name like "杭州市西湖区".
@MainActor
final class LocationProvider: NSObject, ObservableObject, CLLocationManagerDelegate {
    struct Place: Equatable {
        var name: String
        var latitude: Double
        var longitude: Double
    }

    @Published private(set) var isResolving = false
    @Published var errorMessage: String?

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    var denied: Bool {
        manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted
    }

    /// Request permission (if needed) and resolve one place. Returns nil if the
    /// user denied access or the lookup failed.
    func currentPlace() async -> Place? {
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
        guard !denied else { errorMessage = "需要定位权限，请在设置中开启。"; return nil }

        isResolving = true
        defer { isResolving = false }

        let location: CLLocation? = await withCheckedContinuation { cont in
            self.locationContinuation = cont
            manager.requestLocation()
        }
        guard let location else { return nil }

        // Reverse geocode → "市 + 区/县" style name.
        let geocoder = CLGeocoder()
        let name: String
        if let placemark = try? await geocoder.reverseGeocodeLocation(
            location, preferredLocale: Locale(identifier: "zh_CN")
        ).first {
            name = [placemark.locality, placemark.subLocality]
                .compactMap { $0 }.joined()
                .ifEmpty(placemark.name ?? "当前位置")
        } else {
            name = "当前位置"
        }
        return Place(name: name, latitude: location.coordinate.latitude,
                     longitude: location.coordinate.longitude)
    }

    // MARK: CLLocationManagerDelegate (bridged to async via a continuation)

    private var locationContinuation: CheckedContinuation<CLLocation?, Never>?

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            locationContinuation?.resume(returning: locations.last)
            locationContinuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            locationContinuation?.resume(returning: nil)
            locationContinuation = nil
        }
    }
}

private extension String {
    func ifEmpty(_ fallback: String) -> String { isEmpty ? fallback : self }
}
