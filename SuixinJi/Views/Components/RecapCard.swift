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
                    .scaledFont(13, weight: .semibold)
                    .foregroundStyle(.secondary)
                Spacer()
                if let mood = recap.topMood { Text(mood).scaledFont(22) }
            }

            Text(recap.monthKey)
                .scaledFont(26, weight: .bold)
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
                .strokeBorder(Color.accentColor.opacity(0.25), lineWidth: forExport ? 2 : 0)
        )
    }

    private func metric(_ value: String, _ title: String, big: Bool = true) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .scaledFont(big ? 28 : 22, weight: .bold)
                .foregroundStyle(big ? Color.accentColor : .primary)
                .monospacedDigit()
            Text(title).scaledFont(12).foregroundStyle(.secondary)
        }
    }

    private func label(system: String, text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: system).scaledFont(13).foregroundStyle(Color.accentColor)
            Text(text).scaledFont(13).foregroundStyle(.secondary)
        }
    }
}
