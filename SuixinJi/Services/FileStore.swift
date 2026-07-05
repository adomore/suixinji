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
    private let root: URL

    /// - Parameter root: base directory for `images/` and `audios/`. Defaults to
    ///   the app-sandbox Documents dir; tests inject a temp dir for isolation.
    init(root: URL? = nil) {
        self.root = root ?? fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        for dir in [imagesDir, audiosDir] {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }

    var imagesDir: URL { root.appendingPathComponent("images", isDirectory: true) }
    var audiosDir: URL { root.appendingPathComponent("audios", isDirectory: true) }

    // MARK: URLs

    func imageURL(_ name: String) -> URL { imagesDir.appendingPathComponent(name) }
    func audioURL(_ name: String) -> URL { audiosDir.appendingPathComponent(name) }

    // MARK: Images

    /// Longest edge allowed on stored images (PRD §3.2 F4).
    static let maxImageEdge: CGFloat = 2048

    /// Compress to long edge ≤ 2048px and persist as JPEG. Returns the file name.
    func saveImage(_ image: UIImage) throws -> String {
        let resized = Self.downscale(image, maxEdge: Self.maxImageEdge)
        guard let data = resized.jpegData(compressionQuality: 0.82) else {
            throw StoreError.encodingFailed
        }
        let name = "\(UUID().uuidString).jpg"
        try data.write(to: imageURL(name), options: .atomic)
        return name
    }

    /// Scale so the longer edge is at most `maxEdge`, preserving aspect ratio.
    /// Images already within bounds are returned unchanged. Exposed for tests.
    static func downscale(_ image: UIImage, maxEdge: CGFloat) -> UIImage {
        let longest = max(image.size.width, image.size.height)
        guard longest > maxEdge else { return image }
        let scale = maxEdge / longest
        let target = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }

    func loadImage(_ name: String) -> UIImage? {
        UIImage(contentsOfFile: imageURL(name).path)
    }

    /// Restore a media file verbatim (used by backup import). Routes by extension.
    func writeMedia(name: String, data: Data) throws {
        let url = name.lowercased().hasSuffix(".m4a") ? audioURL(name) : imageURL(name)
        try data.write(to: url, options: .atomic)
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
