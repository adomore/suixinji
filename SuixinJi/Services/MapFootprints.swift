import Foundation
import CoreLocation

/// Groups located diary entries into map "footprints" (evolution · 地图足迹).
/// Pure and testable — the view (`MapView`) just renders what this returns.
///
/// Entries already carry `latitude`/`longitude`/`locationName` (F14). Points that
/// fall in the same coarse grid cell are merged into one `Place` so the same spot
/// shows a single pin with a count instead of a pile of overlapping markers.
enum MapFootprints {

    /// One map pin: a cluster of entries sharing a grid cell.
    struct Place: Identifiable {
        let id: String                       // the grid-cell key
        let coordinate: CLLocationCoordinate2D
        let name: String?                    // most-recent non-empty locationName
        let entries: [DiaryEntry]            // newest-first
        var count: Int { entries.count }
    }

    /// Grid precision in degrees (~55 m at 0.0005°). Nearby points within one cell
    /// merge. Coarser = fewer, chunkier pins; finer = more, spread-out pins.
    /// Grid bucketing has a boundary effect: two points straddling a cell edge stay
    /// separate even if physically close. Same-spot GPS readings cluster in practice;
    /// exact radius clustering (DBSCAN etc.) would be the next step if it ever matters.
    static let gridPrecision = 0.0005

    /// Cluster located entries into places, biggest cluster first (ties by id, so
    /// the ordering is deterministic).
    static func places(from entries: [DiaryEntry], precision: Double = gridPrecision) -> [Place] {
        var buckets: [String: [DiaryEntry]] = [:]
        for e in entries {
            guard let lat = e.latitude, let lon = e.longitude else { continue } // no coordinate → skip
            buckets[gridKey(lat: lat, lon: lon, precision: precision), default: []].append(e)
        }
        return buckets.map { key, members in
            let newestFirst = members.sorted { $0.createdAt > $1.createdAt }
            let lat = members.reduce(0) { $0 + ($1.latitude ?? 0) } / Double(members.count)
            let lon = members.reduce(0) { $0 + ($1.longitude ?? 0) } / Double(members.count)
            let name = newestFirst.first { !($0.locationName ?? "").isEmpty }?.locationName
            return Place(id: key,
                         coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                         name: name,
                         entries: newestFirst)
        }
        .sorted { ($0.count, $1.id) > ($1.count, $0.id) }
    }

    /// A stable key for the grid cell a coordinate falls into. Same cell → same key.
    static func gridKey(lat: Double, lon: Double, precision: Double = gridPrecision) -> String {
        let rLat = (lat / precision).rounded() * precision
        let rLon = (lon / precision).rounded() * precision
        return String(format: "%.5f,%.5f", rLat, rLon)
    }
}
