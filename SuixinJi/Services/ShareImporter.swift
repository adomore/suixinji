import Foundation
import SwiftData
import UIKit

/// Drains the Share Extension's `ShareInbox` into new diary entries (evolution).
/// Runs on app launch / becoming active. Each pending share becomes one entry via
/// the normal `DiaryService.save` path (images compressed through `FileStore`,
/// Spotlight + media sync updated), then its inbox files are removed.
enum ShareImporter {
    @discardableResult
    @MainActor
    static func importPending(into context: ModelContext,
                              fileStore: FileStoreImpl = FileStore.shared) -> Int {
        let shares = ShareInbox.pending()
        guard !shares.isEmpty else { return 0 }

        var imported = 0
        for share in shares {
            var draft = DiaryDraft()
            draft.text = share.text.trimmingCharacters(in: .whitespacesAndNewlines)
            draft.images = share.imageFileNames.compactMap { name in
                ShareInbox.imageData(name).flatMap { UIImage(data: $0) }.map { EditorImage.new($0, UUID()) }
            }
            // Skip empty payloads (no text, no image) — nothing worth saving.
            if draft.hasContent, (try? DiaryService.save(draft, existing: nil, into: context, fileStore: fileStore)) != nil {
                imported += 1
            }
            ShareInbox.remove(share) // always clear, even if skipped, so it can't pile up
        }
        return imported
    }
}
