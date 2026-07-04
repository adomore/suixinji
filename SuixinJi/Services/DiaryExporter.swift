import SwiftUI
import UIKit

/// Exports a diary entry (F13):
///  • `exportPDF` — a real multi-page A4 PDF (the tall render is sliced into pages).
///  • `exportLongImage` — a single tall PNG ("长图") for sharing to chat/social.
/// Both render one print-friendly SwiftUI layout with `ImageRenderer`.
@MainActor
enum DiaryExporter {
    /// Canvas width the layout is rendered at (points).
    static let contentWidth: CGFloat = 750

    /// Rasterize the entry's export layout to a single tall image (@2x).
    private static func renderImage(_ entry: DiaryEntry) -> UIImage? {
        let renderer = ImageRenderer(content: ExportDocument(entry: entry).frame(width: contentWidth))
        renderer.proposedSize = ProposedViewSize(width: contentWidth, height: nil)
        renderer.scale = 2
        return renderer.uiImage
    }

    private static func tempURL(_ ext: String, _ entry: DiaryEntry) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("随心记-\(DiaryDateFormat.shortChinese(entry.diaryDate)).\(ext)")
    }

    // MARK: Long image (F13)

    static func exportLongImage(_ entry: DiaryEntry) -> URL? {
        guard let image = renderImage(entry), let data = image.pngData() else { return nil }
        let url = tempURL("png", entry)
        do { try data.write(to: url, options: .atomic); return url } catch { return nil }
    }

    // MARK: Paginated PDF (F13)

    static func exportPDF(_ entry: DiaryEntry) -> URL? {
        guard let image = renderImage(entry), let cg = image.cgImage else { return nil }

        let pageSize = CGSize(width: 595, height: 842) // A4 @72dpi
        let imgW = CGFloat(cg.width), imgH = CGFloat(cg.height)
        let scale = pageSize.width / imgW                 // fit image width to the page
        let sliceHeightPx = pageSize.height / scale        // image pixels shown per page

        let url = tempURL("pdf", entry)
        let pdf = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))
        do {
            try pdf.writePDF(to: url) { ctx in
                var y: CGFloat = 0
                while y < imgH {
                    ctx.beginPage()
                    let sliceH = min(sliceHeightPx, imgH - y)
                    if let slice = cg.cropping(to: CGRect(x: 0, y: y, width: imgW, height: sliceH)) {
                        UIImage(cgImage: slice).draw(
                            in: CGRect(x: 0, y: 0, width: pageSize.width, height: sliceH * scale)
                        )
                    }
                    y += sliceHeightPx
                }
            }
            return url
        } catch {
            return nil
        }
    }
}

/// The print layout for one entry (shared by PDF + long image).
private struct ExportDocument: View {
    let entry: DiaryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("随心记").font(.system(size: 15, weight: .semibold)).foregroundStyle(.secondary)
            Text(DiaryDateFormat.longChinese(entry.diaryDate)).font(.system(size: 26, weight: .bold))

            HStack(spacing: 10) {
                if let mood = entry.mood { Text(mood).font(.system(size: 24)) }
                if let weather = entry.weather { Text(weather).font(.system(size: 24)) }
                if let wt = entry.weatherText { Text(wt).font(.system(size: 15)).foregroundStyle(.secondary) }
                if let loc = entry.locationName {
                    Text(loc).font(.system(size: 14)).foregroundStyle(.secondary)
                }
            }

            if entry.hasAudio, let d = entry.audioDuration {
                Text("🎙️ 语音 \(DiaryDateFormat.duration(d))")
                    .font(.system(size: 15)).foregroundStyle(.secondary)
            }

            if !entry.text.isEmpty {
                Text(entry.text).font(.system(size: 17)).lineSpacing(6)
            }

            if !entry.tags.isEmpty {
                Text(entry.tags.map { "#\($0)" }.joined(separator: "  "))
                    .font(.system(size: 14)).foregroundStyle(Color.brand)
            }

            ForEach(entry.imageFileNames, id: \.self) { name in
                if let img = FileStore.shared.loadImage(name) {
                    Image(uiImage: img).resizable().scaledToFit()
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
    }
}
