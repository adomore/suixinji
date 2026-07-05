import SwiftUI

/// A shareable 年度报告 · Year in Review card (evolution). Shown in 统计 and
/// rendered to a long image by `DiaryExporter.exportYearReview`. Calm look,
/// accent for emphasis — mirrors `RecapCard`.
struct YearReviewCard: View {
    let review: YearReview
    /// `true` when rendered for export (opaque light background, accent border).
    var forExport = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("随心记 · 年度报告")
                    .scaledFont(13, weight: .semibold)
                    .foregroundStyle(.secondary)
                Spacer()
                if let mood = review.topMood { Text(mood).scaledFont(24) }
            }

            Text("\(String(review.year)) 年")
                .scaledFont(30, weight: .bold)
                .foregroundStyle(.primary)

            HStack(spacing: 22) {
                metric("\(review.entryCount)", "篇日记")
                metric("\(review.daysWritten)", "天记录")
                if review.longestStreak > 1 { metric("\(review.longestStreak)", "最长连记") }
            }

            if let month = review.topMonth {
                row(system: "calendar", text: "最勤快的月份 · \(month)（\(review.topMonthCount) 篇）")
            }
            if review.placesCount > 0 {
                row(system: "map", text: "去过 \(review.placesCount) 个地方")
            }
            if review.withPhotos > 0 || review.withAudio > 0 {
                HStack(spacing: 16) {
                    if review.withPhotos > 0 { row(system: "photo", text: "\(review.withPhotos) 篇有照片") }
                    if review.withAudio > 0 { row(system: "waveform", text: "\(review.withAudio) 篇有录音") }
                }
            }

            if !review.topTags.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("高频标签").scaledFont(12).foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        ForEach(review.topTags, id: \.tag) { t in
                            Text("#\(t.tag) · \(t.count)")
                                .scaledFont(13, weight: .medium)
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(Color.accentColor.opacity(0.12), in: Capsule())
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            forExport ? AnyShapeStyle(Color.white)
                      : AnyShapeStyle(Color(uiColor: .secondarySystemGroupedBackground)),
            in: RoundedRectangle(cornerRadius: Layout.cardRadius, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Layout.cardRadius, style: .continuous)
                .strokeBorder(Color.accentColor.opacity(0.25), lineWidth: forExport ? 2 : 0)
        )
    }

    private func metric(_ value: String, _ title: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).scaledFont(28, weight: .bold)
                .foregroundStyle(Color.accentColor).monospacedDigit()
            Text(title).scaledFont(12).foregroundStyle(.secondary)
        }
    }

    private func row(system: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: system).scaledFont(13).foregroundStyle(Color.accentColor)
            Text(text).scaledFont(14).foregroundStyle(.primary)
        }
    }
}
