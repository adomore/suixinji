import Foundation
import CloudKit

/// Reports the device's iCloud account status for the Settings row (F11).
enum CloudStatus {
    static func current() async -> CKAccountStatus {
        (try? await CKContainer.default().accountStatus()) ?? .couldNotDetermine
    }

    static func describe(_ status: CKAccountStatus) -> String {
        switch status {
        case .available: return "已开启"
        case .noAccount: return "未登录 iCloud"
        case .restricted: return "受限"
        case .temporarilyUnavailable: return "暂时不可用"
        default: return "不可用"
        }
    }
}
