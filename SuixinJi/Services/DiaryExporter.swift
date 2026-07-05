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

    // MARK: Monthly recap card (evolution) — a shareable long image

    static func exportRecap(_ recap: MonthlyRecap) -> URL? {
        let width: CGFloat = 640
        let renderer = ImageRenderer(
            content: RecapCard(recap: recap, forExport: true)
                .frame(width: width)
                .padding(20)
                .background(Color.white)
                .environment(\.colorScheme, .light)
        )
        renderer.proposedSize = ProposedViewSize(width: width + 40, height: nil)
        renderer.scale = 2
        guard let image = renderer.uiImage, let data = image.pngData() else { return nil }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("随心记-回顾-\(recap.monthKey).png")
        do { try data.write(to: url, options: .atomic); return url } catch { return nil }
    }

    static func exportYearReview(_ review: YearReview) -> URL? {
        let width: CGFloat = 640
        let renderer = ImageRenderer(
            content: YearReviewCard(review: review, forExport: true)
                .frame(width: width)
                .padding(20)
                .background(Color.white)
                .environment(\.colorScheme, .light)
        )
        renderer.proposedSize = ProposedViewSize(width: width + 40, height: nil)
        renderer.scale = 2
        guard let image = renderer.uiImage, let data = image.pngData() else { return nil }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("随心记-年度报告-\(review.year).png")
        do { try data.write(to: url, options: .atomic); return url } catch { return nil }
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

    // MARK: 整本导出 · 电子书 PDF (evolution)

    /// Render the whole diary into one paginated A4 PDF: a cover, then a chapter per
    /// month (chronological). Each chapter (and the cover) is rendered on its own
    /// canvas and sliced across pages, so no single image grows unbounded.
    static func exportBook(from entries: [DiaryEntry], now: Date = Date(),
                           calendar: Calendar = Calendar(identifier: .gregorian)) -> URL? {
        guard !entries.isEmpty else { return nil }
        let chapters = BookExport.chapters(from: entries, calendar: calendar)
        let pageSize = CGSize(width: 595, height: 842) // A4 @72dpi

        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("随心记全集-\(f.string(from: now)).pdf")

        let pdf = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))
        do {
            try pdf.writePDF(to: url) { ctx in
                let range = BookExport.dateRange(of: entries, calendar: calendar)
                if let cover = render(BookCover(count: entries.count, range: range,
                                                generated: f.string(from: now))) {
                    drawPages(cover, in: ctx, pageSize: pageSize)
                }
                for chapter in chapters {
                    if let page = render(BookChapter(title: chapter.title, entries: chapter.entries)) {
                        drawPages(page, in: ctx, pageSize: pageSize)
                    }
                }
            }
            return url
        } catch {
            return nil
        }
    }

    /// Rasterize any export view to a single tall CGImage (@2x) at `contentWidth`.
    private static func render<V: View>(_ view: V) -> CGImage? {
        let renderer = ImageRenderer(content: view.frame(width: contentWidth))
        renderer.proposedSize = ProposedViewSize(width: contentWidth, height: nil)
        renderer.scale = 2
        return renderer.uiImage?.cgImage
    }

    /// Slice a tall image across A4 pages, starting a fresh page for this image.
    private static func drawPages(_ cg: CGImage, in ctx: UIGraphicsPDFRendererContext, pageSize: CGSize) {
        let imgW = CGFloat(cg.width), imgH = CGFloat(cg.height)
        guard imgW > 0, imgH > 0 else { return }
        let scale = pageSize.width / imgW
        let sliceHeightPx = pageSize.height / scale
        var y: CGFloat = 0
        while y < imgH {
            ctx.beginPage()
            let sliceH = min(sliceHeightPx, imgH - y)
            if let slice = cg.cropping(to: CGRect(x: 0, y: y, width: imgW, height: sliceH)) {
                UIImage(cgImage: slice).draw(in: CGRect(x: 0, y: 0, width: pageSize.width, height: sliceH * scale))
            }
            y += sliceHeightPx
        }
    }
}

/// 整本导出 (evolution). Pure grouping of the diary into chapters (one per month,
/// chronological). Kept free of UIKit so it's unit-testable.
enum BookExport {
    struct Chapter {
        let key: String      // "yyyy-MM"
        let title: String    // e.g. "2026年7月"
        let entries: [DiaryEntry]
    }

    static func chapters(from entries: [DiaryEntry],
                         calendar: Calendar = Calendar(identifier: .gregorian)) -> [Chapter] {
        let sorted = entries.sorted { $0.diaryDate < $1.diaryDate } // oldest first
        var order: [String] = []
        var byKey: [String: [DiaryEntry]] = [:]
        for e in sorted {
            let c = calendar.dateComponents([.year, .month], from: e.diaryDate)
            let key = String(format: "%04d-%02d", c.year ?? 0, c.month ?? 0)
            if byKey[key] == nil { order.append(key) }
            byKey[key, default: []].append(e)
        }
        return order.map { key in
            let parts = key.split(separator: "-")
            let y = Int(parts.first ?? "") ?? 0
            let m = Int(parts.last ?? "") ?? 0
            return Chapter(key: key, title: "\(y)年\(m)月", entries: byKey[key] ?? [])
        }
    }

    /// "2025年1月 – 2026年7月" (or a single month) for the cover.
    static func dateRange(of entries: [DiaryEntry],
                          calendar: Calendar = Calendar(identifier: .gregorian)) -> String {
        let dates = entries.map(\.diaryDate).sorted()
        guard let first = dates.first, let last = dates.last else { return "" }
        func label(_ d: Date) -> String {
            let c = calendar.dateComponents([.year, .month], from: d)
            return "\(c.year ?? 0)年\(c.month ?? 0)月"
        }
        let a = label(first), b = label(last)
        return a == b ? a : "\(a) – \(b)"
    }
}

/// Book cover page.
private struct BookCover: View {
    let count: Int
    let range: String
    let generated: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Spacer(minLength: 120)
            Text("随心记").scaledFont(46, weight: .bold)
            Text("我的日记 · 全集").scaledFont(22).foregroundStyle(.secondary)
            Spacer(minLength: 60)
            if !range.isEmpty { Text(range).scaledFont(17).foregroundStyle(.secondary) }
            Text("共 \(count) 篇").scaledFont(17).foregroundStyle(.secondary)
            Text("导出于 \(generated)").scaledFont(14).foregroundStyle(.tertiary)
            Spacer(minLength: 120)
        }
        .padding(50)
        .frame(maxWidth: .infinity, minHeight: 1000, alignment: .leading)
        .background(Color.white)
    }
}

/// One month chapter: a header plus each entry, divided.
private struct BookChapter: View {
    let title: String
    let entries: [DiaryEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text(title).scaledFont(30, weight: .bold)
            ForEach(entries) { entry in
                BookEntryBlock(entry: entry)
                if entry.id != entries.last?.id { Divider() }
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
    }
}

/// One entry inside a chapter (compact print layout).
private struct BookEntryBlock: View {
    let entry: DiaryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(DiaryDateFormat.longChinese(entry.diaryDate)).scaledFont(18, weight: .semibold)
                if let mood = entry.mood { Text(mood).scaledFont(18) }
                if let weather = entry.weather { Text(weather).scaledFont(18) }
                Spacer()
            }
            if let loc = entry.locationName {
                Text(loc).scaledFont(13).foregroundStyle(.secondary)
            }
            if !entry.text.isEmpty {
                Text(entry.text).scaledFont(16).lineSpacing(5)
            }
            if !entry.tags.isEmpty {
                Text(entry.tags.map { "#\($0)" }.joined(separator: "  "))
                    .scaledFont(13).foregroundStyle(Color.accentColor)
            }
            ForEach(entry.imageFileNames, id: \.self) { name in
                if let img = FileStore.shared.loadImage(name) {
                    Image(uiImage: img).resizable().scaledToFit()
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The print layout for one entry (shared by PDF + long image).
private struct ExportDocument: View {
    let entry: DiaryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("随心记").scaledFont(15, weight: .semibold).foregroundStyle(.secondary)
            Text(DiaryDateFormat.longChinese(entry.diaryDate)).scaledFont(26, weight: .bold)

            HStack(spacing: 10) {
                if let mood = entry.mood { Text(mood).scaledFont(24) }
                if let weather = entry.weather { Text(weather).scaledFont(24) }
                if let wt = entry.weatherText { Text(wt).scaledFont(15).foregroundStyle(.secondary) }
                if let loc = entry.locationName {
                    Text(loc).scaledFont(14).foregroundStyle(.secondary)
                }
            }

            if entry.hasAudio, let d = entry.audioDuration {
                Text("🎙️ 语音 \(DiaryDateFormat.duration(d))")
                    .scaledFont(15).foregroundStyle(.secondary)
            }

            if !entry.text.isEmpty {
                Text(entry.text).scaledFont(17).lineSpacing(6)
            }

            if !entry.tags.isEmpty {
                Text(entry.tags.map { "#\($0)" }.joined(separator: "  "))
                    .scaledFont(14).foregroundStyle(Color.accentColor)
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
