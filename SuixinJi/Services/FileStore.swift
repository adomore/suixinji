import Foundation
import UIKit

/// Owns the app-sandbox file layout described in 随心记-PRD.md §5.3:
///
///     Documents/
///     ├── images/   UUID.jpg   (long edge ≤ 2048px, JPEG)
///     └── audios/   UUID.m4a
///
/// The rule the PRD hammers on: files are written on *save* and deleted together
/// with the DB record, so no orphan files pile up.
enum FileStore {
    static let shared = FileStoreImpl()
}

final class FileStoreImpl {
    private let fm = FileManager.default

    private var documents: URL {
        fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    var imagesDir: URL { documents.appendingPathComponent("images", isDirectory: true) }
    var audiosDir: URL { documents.appendingPathComponent("audios", isDirectory: true) }

    init() {
        for dir in [imagesDir, audiosDir] {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }

    // MARK: URLs

    func imageURL(_ name: String) -> URL { imagesDir.appendingPathComponent(name) }
    func audioURL(_ name: String) -> URL { audiosDir.appendingPathComponent(name) }

    // MARK: Images

    /// Compress to long edge ≤ 2048px and persist as JPEG. Returns the file name.
    func saveImage(_ image: UIImage) throws -> String {
        let resized = image.downscaled(maxEdge: 2048)
        guard let data = resized.jpegData(compressionQuality: 0.82) else {
            throw StoreError.encodingFailed
        }
        let name = "\(UUID().uuidString).jpg"
        try data.write(to: imageURL(name), options: .atomic)
        return name
    }

    func loadImage(_ name: String) -> UIImage? {
        UIImage(contentsOfFile: imageURL(name).path)
    }

    // MARK: Audio

    /// Move a freshly-recorded temp file into `audios/` under a UUID name.
    func adoptAudio(tempURL: URL) throws -> String {
        let name = "\(UUID().uuidString).m4a"
        let dest = audioURL(name)
        if fm.fileExists(atPath: dest.path) { try fm.removeItem(at: dest) }
        try fm.moveItem(at: tempURL, to: dest)
        return name
    }

    // MARK: Deletion

    func deleteImage(_ name: String) { try? fm.removeItem(at: imageURL(name)) }
    func deleteAudio(_ name: String) { try? fm.removeItem(at: audioURL(name)) }

    /// Delete every file an entry references. Call this *before* deleting the
    /// SwiftData record (PRD §5.3 `deleteEntry()`).
    func deleteFiles(for entry: DiaryEntry) {
        entry.imageFileNames.forEach(deleteImage)
        if let audio = entry.audioFileName { deleteAudio(audio) }
    }

    enum StoreError: LocalizedError {
        case encodingFailed
        var errorDescription: String? {
            switch self {
            case .encodingFailed: return "图片处理失败，请重试。"
            }
        }
    }
}

private extension UIImage {
    /// Scale so the longer edge is at most `maxEdge`, preserving aspect ratio.
    func downscaled(maxEdge: CGFloat) -> UIImage {
        let longest = max(size.width, size.height)
        guard longest > maxEdge else { return self }
        let scale = maxEdge / longest
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
