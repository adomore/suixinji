import SwiftUI
import UIKit

/// Exports a diary entry to a shareable PDF (F13). Renders a print-friendly
/// SwiftUI layout with `ImageRenderer` and writes a temp `.pdf` the share sheet
/// can hand off. Images are included; audio is noted as a "🎙️ 语音 mm:ss" line.
@MainActor
enum DiaryExporter {

    /// Produce a temporary PDF file for `entry`; returns its URL (nil on failure).
    static func exportPDF(_ entry: DiaryEntry) -> URL? {
        let page = CGSize(width: 595, height: 842) // A4 @72dpi
        let renderer = ImageRenderer(content: ExportDocument(entry: entry).frame(width: page.width))
        renderer.proposedSize = ProposedViewSize(width: page.width, height: nil)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("随心记-\(DiaryDateFormat.shortChinese(entry.diaryDate)).pdf")

        var box = CGRect(origin: .zero, size: page)
        guard let consumer = CGDataConsumer(url: url as CFURL),
              let pdf = CGContext(consumer: consumer, mediaBox: &box, nil) else { return nil }

        renderer.render { size, renderInContext in
            // Paginate: the content can be taller than one page.
            let pageCount = max(1, Int(ceil(size.height / page.height)))
            for i in 0..<pageCount {
                pdf.beginPDFPage(nil)
                pdf.saveGState()
                // Flip to UIKit's top-left origin and offset by page.
                pdf.translateBy(x: 0, y: page.height)
                pdf.scaleBy(x: 1, y: -1)
                pdf.translateBy(x: 0, y: CGFloat(i) * page.height)
                renderInContext(pdf)
                pdf.restoreGState()
                pdf.endPDFPage()
            }
        }
        pdf.closePDF()
        return url
    }
}

/// The print layout for one entry.
private struct ExportDocument: View {
    let entry: DiaryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("随心记").font(.system(size: 13, weight: .semibold)).foregroundStyle(.secondary)
            Text(DiaryDateFormat.longChinese(entry.diaryDate)).font(.system(size: 22, weight: .bold))

            HStack(spacing: 8) {
                if let mood = entry.mood { Text(mood).font(.system(size: 20)) }
                if let weather = entry.weather { Text(weather).font(.system(size: 20)) }
                if let loc = entry.locationName {
                    Text(loc).font(.system(size: 12)).foregroundStyle(.secondary)
                }
            }

            if entry.hasAudio, let d = entry.audioDuration {
                Text("🎙️ 语音 \(DiaryDateFormat.duration(d))")
                    .font(.system(size: 13)).foregroundStyle(.secondary)
            }

            if !entry.text.isEmpty {
                Text(entry.text).font(.system(size: 15)).lineSpacing(5)
            }

            if !entry.tags.isEmpty {
                Text(entry.tags.map { "#\($0)" }.joined(separator: "  "))
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }

            ForEach(entry.imageFileNames, id: \.self) { name in
                if let img = FileStore.shared.loadImage(name) {
                    Image(uiImage: img).resizable().scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding(40)
        .frame(width: 595, alignment: .leading)
        .background(Color.white)
    }
}
