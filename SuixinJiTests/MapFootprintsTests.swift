import XCTest
@testable import SuixinJi

/// 地图足迹 clustering engine (evolution). Pure functions — no map, no SwiftData.
final class MapFootprintsTests: XCTestCase {

    private func entry(_ text: String, lat: Double?, lon: Double?,
                       place: String? = nil, created: Date = Date()) -> DiaryEntry {
        let e = DiaryEntry(text: text, locationName: place, latitude: lat, longitude: lon)
        e.createdAt = created
        return e
    }

    func testClustersNearbyEntriesIntoOnePlace() {
        // ~11 m apart, same grid cell (both round to 30.00000 / 120.00000).
        let a = entry("a", lat: 30.0001, lon: 120.0001)
        let b = entry("b", lat: 30.0002, lon: 120.0002)
        let places = MapFootprints.places(from: [a, b])
        XCTAssertEqual(places.count, 1)
        XCTAssertEqual(places.first?.count, 2)
    }

    func testSeparatesDistantEntries() {
        let a = entry("a", lat: 30.0000, lon: 120.0000)
        let b = entry("b", lat: 31.5000, lon: 121.5000) // ~150 km away
        let places = MapFootprints.places(from: [a, b])
        XCTAssertEqual(places.count, 2)
        XCTAssertTrue(places.allSatisfy { $0.count == 1 })
    }

    func testSkipsEntriesWithoutCoordinate() {
        let located = entry("here", lat: 30.0, lon: 120.0)
        let noCoord = entry("nowhere", lat: nil, lon: nil, place: "某地")
        let halfCoord = entry("half", lat: 30.0, lon: nil)
        let places = MapFootprints.places(from: [located, noCoord, halfCoord])
        XCTAssertEqual(places.count, 1)
        XCTAssertEqual(places.first?.entries.map(\.text), ["here"])
    }

    func testCentroidIsAverageOfMembers() {
        let a = entry("a", lat: 30.0001, lon: 120.0001)
        let b = entry("b", lat: 30.0002, lon: 120.0002) // same cell
        let place = MapFootprints.places(from: [a, b]).first!
        XCTAssertEqual(place.coordinate.latitude, 30.00015, accuracy: 1e-9)
        XCTAssertEqual(place.coordinate.longitude, 120.00015, accuracy: 1e-9)
    }

    func testNameTakenFromMostRecentLocatedEntry() {
        let old = entry("old", lat: 30.0001, lon: 120.0001, place: "旧地名",
                        created: Date(timeIntervalSince1970: 1_000))
        let new = entry("new", lat: 30.0002, lon: 120.0002, place: "新地名",
                        created: Date(timeIntervalSince1970: 2_000))
        let place = MapFootprints.places(from: [old, new]).first!
        XCTAssertEqual(place.name, "新地名")
        // entries are newest-first
        XCTAssertEqual(place.entries.map(\.text), ["new", "old"])
    }

    func testNameSkipsEmptyLocationNames() {
        let named = entry("named", lat: 30.0001, lon: 120.0001, place: "有名字",
                          created: Date(timeIntervalSince1970: 1_000))
        let blank = entry("blank", lat: 30.0002, lon: 120.0002, place: "",
                          created: Date(timeIntervalSince1970: 2_000)) // newer but blank
        let place = MapFootprints.places(from: [named, blank]).first!
        XCTAssertEqual(place.name, "有名字")
    }

    func testGridKeyStableAndDistinct() {
        let k1 = MapFootprints.gridKey(lat: 30.0001, lon: 120.0001)
        let k2 = MapFootprints.gridKey(lat: 30.0002, lon: 120.0002) // same cell
        let k3 = MapFootprints.gridKey(lat: 30.0100, lon: 120.0100) // far cell
        XCTAssertEqual(k1, k2)
        XCTAssertNotEqual(k1, k3)
    }

    func testEmptyWhenNoLocatedEntries() {
        let places = MapFootprints.places(from: [entry("x", lat: nil, lon: nil)])
        XCTAssertTrue(places.isEmpty)
    }

    func testSortedByCountDescending() {
        // One busy place (3 entries) + one single place → busy first.
        let busy = (0..<3).map { entry("busy\($0)", lat: 30.0, lon: 120.0) }
        let lone = entry("lone", lat: 31.5, lon: 121.5)
        let places = MapFootprints.places(from: busy + [lone])
        XCTAssertEqual(places.map(\.count), [3, 1])
    }
}
