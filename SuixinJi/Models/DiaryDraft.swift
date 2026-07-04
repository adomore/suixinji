import SwiftUI
import UIKit

/// A photo in the editor: either already saved on disk, or freshly picked.
enum EditorImage: Identifiable, Equatable {
    case existing(String)          // file name on disk
    case new(UIImage, UUID)        // in-memory, id for diffing

    var id: String {
        switch self {
        case .existing(let n): return n
        case .new(_, let uuid): return uuid.uuidString
        }
    }

    static func == (lhs: EditorImage, rhs: EditorImage) -> Bool { lhs.id == rhs.id }

    @ViewBuilder
    func thumbnail(side: CGFloat) -> some View {
        switch self {
        case .existing(let name):
            ThumbnailImage(name: name, side: side)
        case .new(let img, _):
            Image(uiImage: img).resizable().scaledToFill()
                .frame(width: side, height: side)
                .clipShape(RoundedRectangle(cornerRadius: Layout.thumbnailRadius, style: .continuous))
        }
    }
}

/// A recording draft.
enum DraftAudio: Equatable {
    case existing(String, TimeInterval)  // saved file name + duration
    case new(URL, TimeInterval)          // temp file + duration

    var duration: TimeInterval {
        switch self {
        case .existing(_, let d), .new(_, let d): return d
        }
    }
}

/// The full editable state of one diary entry, independent of any view.
/// `DiaryService` turns a draft into a persisted `DiaryEntry`.
struct DiaryDraft {
    var text: String = ""
    var diaryDate: Date = Date()
    var images: [EditorImage] = []
    var audio: DraftAudio?

    /// Save is allowed only when there is text, a photo, or a recording (F1).
    var hasContent: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !images.isEmpty
            || audio != nil
    }
}
