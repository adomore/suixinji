import SwiftUI
import SwiftData

/// Insights screen (evolution beyond the PRD). Streaks, monthly activity, mood
/// distribution, media counts. Kept calm per the Brief — accent only for
/// emphasis, semantic colors elsewhere, no gradients.
struct StatisticsView: View {
    @Query private var entries: [DiaryEntry]
    @Environment(\.dismiss) private var dismiss

    private var stats: DiaryStatistics { DiaryStatistics.compute(from: entries) }

    var body: some View {
        NavigationStack {
            Group {
                if entries.isEmpty {
                    emptyState
                } else {
                    content
                }
            }
            .background(Color.groupedBackground.ignoresSafeArea())
            .navigationTitle("统计")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("完成") { dismiss() } }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.bar.xaxis").font(.system(size: 30)).foregroundStyle(.tertiary)
            Text("还没有可统计的数据").font(.summary15).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                tiles
                if !stats.moods.isEmpty { moodSection }
                if stats.months.count > 1 { monthSection }
                mediaSection
            }
            .padding(Layout.pageMargin)
            .padding(.bottom, 24)
        }
    }

    // MARK: Stat tiles

    private var tiles: some View {
        let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
        return LazyVGrid(columns: columns, spacing: 12) {
            StatTile(value: "\(stats.currentStreak)", unit: "天",
                     title: "连续记录", accent: true,
                     footnote: stats.longestStreak > 0 ? "最长 \(stats.longestStreak) 天" : nil)
            StatTile(value: "\(stats.totalEntries)", unit: "篇", title: "累计日记")
            StatTile(value: "\(stats.entriesThisMonth)", unit: "篇", title: "本月")
            StatTile(value: "\(stats.daysWritten)", unit: "天", title: "记录天数")
        }
    }

    // MARK: Mood distribution

    private var moodSection: some View {
        let maxCount = stats.moods.map(\.count).max() ?? 1
        return VStack(alignment: .leading, spacing: 12) {
            sectionHeader("心情分布")
            VStack(spacing: 10) {
                ForEach(stats.moods) { mood in
                    HStack(spacing: 10) {
                        Text(mood.emoji).font(.system(size: 20)).frame(width: 26)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color(uiColor: .tertiarySystemFill))
                                Capsule().fill(Color.brand)
                                    .frame(width: max(6, geo.size.width * CGFloat(mood.count) / CGFloat(maxCount)))
                            }
                        }
                        .frame(height: 10)
                        Text("\(mood.count)").font(.aux13).monospacedDigit()
                            .foregroundStyle(.secondary).frame(width: 28, alignment: .trailing)
                    }
                }
            }
            .cardBackgroundStyle()
        }
    }

    // MARK: Monthly activity

    private var monthSection: some View {
        let maxCount = stats.months.map(\.count).max() ?? 1
        return VStack(alignment: .leading, spacing: 12) {
            sectionHeader("月度活跃")
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(stats.months) { month in
                    VStack(spacing: 6) {
                        Text("\(month.count)").font(.aux13).monospacedDigit().foregroundStyle(.secondary)
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Color.brand.opacity(0.85))
                            .frame(height: max(6, 90 * CGFloat(month.count) / CGFloat(maxCount)))
                        Text(month.key.replacingOccurrences(of: "年", with: "/").replacingOccurrences(of: "月", with: ""))
                            .font(.system(size: 10)).foregroundStyle(.tertiary)
                            .lineLimit(1).minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 130, alignment: .bottom)
            .cardBackgroundStyle()
        }
    }

    // MARK: Media

    private var mediaSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("媒体")
            HStack(spacing: 12) {
                mediaPill(system: "photo", count: stats.withPhotos, label: "篇有照片")
                mediaPill(system: "waveform", count: stats.withAudio, label: "篇有录音")
            }
        }
    }

    private func mediaPill(system: String, count: Int, label: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: system).font(.system(size: 15)).foregroundStyle(Color.brand)
            Text("\(count)").font(.system(size: 17, weight: .semibold)).monospacedDigit()
            Text(label).font(.aux13).foregroundStyle(.secondary)
            Spacer()
        }
        .cardBackgroundStyle()
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text).font(.groupHeader13).foregroundStyle(.secondary)
    }
}

/// A single number tile. The streak tile is accented; the rest are neutral.
private struct StatTile: View {
    let value: String
    var unit: String = ""
    let title: String
    var accent: Bool = false
    var footnote: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(accent ? Color.brand : .primary)
                    .monospacedDigit()
                if !unit.isEmpty {
                    Text(unit).font(.aux13).foregroundStyle(.secondary)
                }
            }
            Text(title).font(.aux13).foregroundStyle(.secondary)
            if let footnote {
                Text(footnote).font(.system(size: 11)).foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardBackgroundStyle()
    }
}

private extension View {
    /// Shared inset white card look used across the stat sections.
    func cardBackgroundStyle() -> some View {
        self.padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: Layout.cardRadius, style: .continuous))
    }
}

#Preview {
    StatisticsView()
        .modelContainer(for: DiaryEntry.self, inMemory: true)
        .tint(.brand)
}
