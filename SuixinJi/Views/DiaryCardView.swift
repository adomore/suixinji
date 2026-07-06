import SwiftUI

/// One timeline card (UI Brief §4 ①). Info hierarchy, strong → weak:
/// big day number + weekday → 2-line summary → up to 3 photo thumbs (+N) → 🎙️ badge.
struct DiaryCardView: View {
    let entry: DiaryEntry
    /// 私密日记 (evolution): when true, content is hidden behind a lock row and the
    /// mood/weather/audio badges (which would leak information) are suppressed.
    var redacted: Bool = false
    /// 农历 (evolution): show the lunar date next to the weekday.
    @AppStorage("showLunarDate") private var showLunar = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row: day number + weekday, and the recording badge (if any).
            HStack(alignment: .center, spacing: 6) {
                Text(DiaryDateFormat.dayNumber(entry.diaryDate))
                    .scaledFont(22, weight: .semibold)
                    .foregroundStyle(.primary)
                Text(DiaryDateFormat.weekdayShort(entry.diaryDate))
                    .scaledFont(13)
                    .foregroundStyle(.secondary)
                if showLunar {
                    Text(LunarDate.format(entry.diaryDate))
                        .scaledFont(12)
                        .foregroundStyle(.tertiary)
                }
                if let festival = Festival.name(for: entry.diaryDate) {
                    Text(LocalizedStringKey(festival))
                        .scaledFont(12, weight: .medium)
                        .foregroundStyle(Color.accentColor)
                }
                Spacer(minLength: 8)
                if redacted {
                    Image(systemName: "lock.fill").scaledFont(14).foregroundStyle(.secondary)
                } else {
                    if let mood = entry.mood { Text(mood).scaledFont(15) }
                    if let weather = entry.weather { Text(weather).scaledFont(15) }
                    if entry.hasAudio, let dur = entry.audioDuration {
                        HStack(spacing: 4) {
                            WaveformBadgeMark()
                            Text(DiaryDateFormat.duration(dur))
                                .scaledFont(13)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if redacted {
                lockedRow.padding(.top, 8)
            } else {
                if !summaryText.isEmpty {
                    Text(summaryText)
                        .scaledFont(15)
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
        }
        .padding(Layout.cardPadding)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Layout.cardRadius, style: .continuous))
    }

    /// The redacted stand-in shown for a locked private entry.
    private var lockedRow: some View {
        HStack(spacing: 8) {
            Text("私密日记")
                .scaledFont(15)
                .foregroundStyle(.secondary)
            Spacer(minLength: 6)
            Text("轻点解锁")
                .scaledFont(13)
                .foregroundStyle(Color.accentColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var summaryText: String {
        // Strip Markdown markers so the card preview reads clean (evolution).
        // Fall back to the raw text if stripping leaves nothing (e.g. a divider-
        // only entry) so a non-empty entry never shows a blank card.
        let preview = MarkdownParser.plainPreview(entry.text).trimmingCharacters(in: .whitespacesAndNewlines)
        return preview.isEmpty ? entry.text.trimmingCharacters(in: .whitespacesAndNewlines) : preview
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
                                    .scaledFont(15, weight: .semibold)
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
