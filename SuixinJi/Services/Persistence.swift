import Foundation
import SwiftData

/// Builds the app's `ModelContainer` (PRD §5.1). iCloud sync (F11) is on by
/// default via SwiftData + CloudKit, but degrades gracefully: if the CloudKit
/// container can't be created (entitlement missing / not provisioned), it falls
/// back to a purely local store instead of crashing. UI tests use an in-memory
/// store. The `DiaryEntry` schema is CloudKit-compatible (all attributes
/// optional or defaulted, no unique constraints, no required relationships).
///
/// Note: CloudKit syncs the diary *records* (text + all metadata + file names).
/// The media files themselves live in the sandbox and are not synced by this
/// step — see BUILD.md.
enum Persistence {
    /// Both synced models: the diary records and the media blobs (F11 media step).
    static let models: [any PersistentModel.Type] = [DiaryEntry.self, MediaBlob.self]

    static func container(inMemory: Bool = false, cloudKit: Bool = true) -> ModelContainer {
        if inMemory {
            return makeLocal(inMemory: true)
        }
        if cloudKit {
            do {
                return try ModelContainer(
                    for: Schema(models),
                    configurations: ModelConfiguration(cloudKitDatabase: .automatic)
                )
            } catch {
                // Entitlement missing / CloudKit unavailable → local, no crash.
                return makeLocal(inMemory: false)
            }
        }
        return makeLocal(inMemory: false)
    }

    private static func makeLocal(inMemory: Bool) -> ModelContainer {
        do {
            return try ModelContainer(
                for: Schema(models),
                configurations: ModelConfiguration(isStoredInMemoryOnly: inMemory)
            )
        } catch {
            fatalError("无法创建数据库容器: \(error)")
        }
    }
}
