import SwiftUI

/// One timeline card (UI Brief §4 ①). Info hierarchy, strong → weak:
/// big day number + weekday → 2-line summary → up to 3 photo thumbs (+N) → 🎙️ badge.
struct DiaryCardView: View {
    let entry: DiaryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row: day number + weekday, and the recording badge (if any).
            HStack(alignment: .center, spacing: 6) {
                Text(DiaryDateFormat.dayNumber(entry.diaryDate))
                    .font(.cardDate22)
                    .foregroundStyle(.primary)
                Text(DiaryDateFormat.weekdayShort(entry.diaryDate))
                    .font(.aux13)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 8)
                if entry.hasAudio, let dur = entry.audioDuration {
                    HStack(spacing: 4) {
                        WaveformBadgeMark()
                        Text(DiaryDateFormat.duration(dur))
                            .font(.aux13)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if !summaryText.isEmpty {
                Text(summaryText)
                    .font(.summary15)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .lineSpacing(2)
                    .padding(.top, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !entry.imageFileNames.isEmpty {
                thumbnailRow.padding(.top, 10)
            }
        }
        .padding(Layout.cardPadding)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Layout.cardRadius, style: .continuous))
    }

    private var summaryText: String {
        entry.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var thumbnailRow: some View {
        let names = entry.imageFileNames
        let shown = Array(names.prefix(Layout.maxThumbsOnCard))
        let overflow = names.count - shown.count
        return HStack(spacing: 6) {
            ForEach(Array(shown.enumerated()), id: \.offset) { idx, name in
                ThumbnailImage(name: name, side: Layout.thumbnail)
                    .overlay {
                        // The last visible thumb carries the "+N" cover when there
                        // are more photos than fit.
                        if idx == shown.count - 1 && overflow > 0 {
                            ZStack {
                                Color.black.opacity(0.35)
                                Text("+\(overflow)")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: Layout.thumbnailRadius, style: .continuous))
                        }
                    }
            }
        }
    }
}

/// Loads a sandbox image by file name; shows a subtle placeholder while missing.
struct ThumbnailImage: View {
    let name: String
    var side: CGFloat

    var body: some View {
        Group {
            if let img = FileStore.shared.loadImage(name) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
            } else {
                Color(uiColor: .tertiarySystemFill)
            }
        }
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: Layout.thumbnailRadius, style: .continuous))
    }
}
