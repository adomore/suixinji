import XCTest
import SwiftData
@testable import SuixinJi

/// Performance baselines for the evolution analytics / filter / render engines —
/// the paths that scan the whole history and would be first to regress into an
/// O(n²) as a diary grows. All run over one realistic ~3,000-entry dataset.
@MainActor
final class EvolutionPerformanceTests: XCTestCase {

    private static let tagPool = ["旅行", "美食", "工作", "家人", "读书", "运动", "心情", "随手记"]
    private static let placePool = ["杭州西湖", "上海外滩", "北京胡同", "成都宽窄巷子",
                                    "广州珠江", "西安钟楼", "厦门鼓浪屿", "重庆洪崖洞"]

    /// Deterministic, varied entries spread across ~3 years (no randomness so the
    /// baseline is stable across runs).
    private func makeDataset(_ n: Int = 3000) -> [DiaryEntry] {
        let cal = Calendar(identifier: .gregorian)
        let today = Date()
        return (0..<n).map { i in
            let day = cal.date(byAdding: .day, value: -(i % 1095), to: today) ?? today
            let mood = (i % 10 < 7) ? DiaryCatalog.moods[i % DiaryCatalog.moods.count] : nil
            let tags = tagsFor(i)
            let hasPlace = i % 2 == 0
            let place = hasPlace ? Self.placePool[i % Self.placePool.count] : nil
            // Cluster coordinates into ~8 places with tiny jitter.
            let baseLat = 30.0 + Double(i % Self.placePool.count) * 0.5
            let baseLon = 120.0 + Double(i % Self.placePool.count) * 0.5
            let lat = hasPlace ? baseLat + Double(i % 3) * 0.0001 : nil
            let lon = hasPlace ? baseLon + Double(i % 3) * 0.0001 : nil
            return DiaryEntry(
                diaryDate: day,
                text: "# 第\(i)天\n今天**心情**不错，去了\(place ?? "家")。\n- 早餐\n- 散步",
                mood: mood,
                weatherText: nil,
                tags: tags,
                locationName: place,
                latitude: lat,
                longitude: lon,
                imageFileNames: (i % 3 == 0) ? ["img\(i).jpg"] : [],
                audioFileName: (i % 7 == 0) ? "aud\(i).m4a" : nil,
                audioDuration: (i % 7 == 0) ? 12 : nil
            )
        }
    }

    private func tagsFor(_ i: Int) -> [String] {
        switch i % 3 {
        case 0: return []
        case 1: return [Self.tagPool[i % Self.tagPool.count]]
        default: return [Self.tagPool[i % Self.tagPool.count],
                         Self.tagPool[(i + 3) % Self.tagPool.count]]
        }
    }

    // MARK: Analytics

    func testStatisticsComputePerformance() {
        let data = makeDataset()
        measure { _ = DiaryStatistics.compute(from: data) }
    }

    func testMoodTrendPerformance() {
        let data = makeDataset()
        measure { _ = MoodTrends.monthlyValence(data, months: 12) }
    }

    func testYearReviewPerformance() {
        let data = makeDataset()
        let year = Calendar(identifier: .gregorian).component(.year, from: Date())
        measure { _ = YearReview.build(from: data, year: year) }
    }

    // MARK: Filter / tags / search

    func testCombinedFilterPerformance() {
        let data = makeDataset()
        var filter = DiaryFilter()
        filter.moods = ["😊", "🙂"]
        filter.tags = ["旅行", "美食"]
        filter.requirePhoto = true
        measure { _ = filter.apply(to: data) }
    }

    func testTagCountsPerformance() {
        let data = makeDataset()
        measure { _ = TagManager.tagCounts(data) }
    }

    func testSearchPerformance() {
        let data = makeDataset()
        measure { _ = DiarySearch.filter(data, query: "散步") }
    }

    // MARK: Map clustering

    func testMapFootprintsPerformance() {
        let data = makeDataset()
        measure { _ = MapFootprints.places(from: data) }
    }

    // MARK: Render-time helpers (per full card list / reindex)

    func testMarkdownPreviewOverListPerformance() {
        let data = makeDataset()
        measure { _ = data.map { MarkdownParser.plainPreview($0.text) } }
    }

    func testSpotlightItemBuildPerformance() {
        let data = makeDataset()
        measure { _ = data.map { SpotlightIndexer.makeItem(for: $0) } }
    }

    // MARK: Memories (scans all history for "on this day")

    func testMemoriesOnThisDayPerformance() {
        let data = makeDataset()
        let cal = Calendar(identifier: .gregorian)
        measure { _ = Memories.onThisDay(data, today: Date(), calendar: cal) }
    }
}
