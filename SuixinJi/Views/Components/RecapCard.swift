import SwiftUI

/// A shareable monthly-recap card (evolution). Shown in the Statistics screen
/// and rendered to a long image by `DiaryExporter.exportRecap`. Restrained look:
/// accent for emphasis, otherwise calm.
struct RecapCard: View {
    let recap: MonthlyRecap
    /// `true` when rendered for export (opaque background, fixed light styling).
    var forExport = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("随心记 · 月度回顾")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if let mood = recap.topMood { Text(mood).font(.system(size: 22)) }
            }

            Text(recap.monthKey)
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.primary)

            HStack(spacing: 22) {
                metric("\(recap.entryCount)", "篇日记")
                metric("\(recap.daysWritten)", "天记录")
                if recap.topMood != nil { metric(recap.topMood!, "最多心情", big: false) }
            }

            if recap.withPhotos > 0 || recap.withAudio > 0 {
                HStack(spacing: 16) {
                    if recap.withPhotos > 0 {
                        label(system: "photo", text: "\(recap.withPhotos) 篇有照片")
                    }
                    if recap.withAudio > 0 {
                        label(system: "waveform", text: "\(recap.withAudio) 篇有录音")
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
                .strokeBorder(Color.brand.opacity(0.25), lineWidth: forExport ? 2 : 0)
        )
    }

    private func metric(_ value: String, _ title: String, big: Bool = true) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: big ? 28 : 22, weight: .bold))
                .foregroundStyle(big ? Color.brand : .primary)
                .monospacedDigit()
            Text(title).font(.system(size: 12)).foregroundStyle(.secondary)
        }
    }

    private func label(system: String, text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: system).font(.system(size: 13)).foregroundStyle(Color.brand)
            Text(text).font(.system(size: 13)).foregroundStyle(.secondary)
        }
    }
}
