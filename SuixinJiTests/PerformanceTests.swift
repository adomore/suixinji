import XCTest
import SwiftData
import UIKit
@testable import SuixinJi

/// Performance baselines. Guards against regressions in the hot paths: timeline
/// grouping over a large history, bulk inserts, and image compression.
@MainActor
final class PerformanceTests: XCTestCase {

    private func date(daysAgo: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
    }

    /// Grouping 1,000 entries spread across ~3 years should be trivially fast.
    func testTimelineGroupingPerformance() {
        let entries = (0..<1000).map { DiaryEntry(diaryDate: date(daysAgo: $0)) }
        measure {
            _ = DiaryTimeline.sections(from: entries)
        }
    }

    /// Inserting 500 entries into an in-memory store.
    func testBulkInsertPerformance() throws {
        measure {
            do {
                let container = try ModelContainer(
                    for: DiaryEntry.self,
                    configurations: ModelConfiguration(isStoredInMemoryOnly: true)
                )
                let context = ModelContext(container)
                for i in 0..<500 {
                    context.insert(DiaryEntry(text: "第\(i)条"))
                }
                try context.save()
            } catch {
                XCTFail("insert failed: \(error)")
            }
        }
    }

    /// Downscaling a 48-megapixel-ish image to the 2048 long-edge cap (F4).
    func testImageDownscalePerformance() {
        let f = UIGraphicsImageRendererFormat.default(); f.scale = 1
        let big = UIGraphicsImageRenderer(size: CGSize(width: 8000, height: 6000), format: f).image { c in
            UIColor.orange.setFill(); c.fill(CGRect(x: 0, y: 0, width: 8000, height: 6000))
        }
        measure {
            _ = FileStoreImpl.downscale(big, maxEdge: 2048)
        }
    }
}
