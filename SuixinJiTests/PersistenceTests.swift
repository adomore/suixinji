import XCTest
import SwiftData
@testable import SuixinJi

/// The persistence factory (F11). The CloudKit path needs an entitlement/account
/// and is verified on device; here we exercise the in-memory path the factory
/// returns for tests.
@MainActor
final class PersistenceTests: XCTestCase {
    func testInMemoryContainerStoresAndFetches() throws {
        let container = Persistence.container(inMemory: true)
        let context = container.mainContext
        context.insert(DiaryEntry(text: "云同步测试"))
        try context.save()

        let all = try context.fetch(FetchDescriptor<DiaryEntry>())
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.text, "云同步测试")
    }
}
