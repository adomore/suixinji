import SwiftUI
import SwiftData
import Charts

/// Insights screen (evolution beyond the PRD). Streaks, monthly activity, mood
/// distribution + trend, media counts. Kept calm per the Brief — accent only for
/// emphasis, semantic colors elsewhere, no gradients.
struct StatisticsView: View {
    @Query private var entries: [DiaryEntry]
    @Environment(\.dismiss) private var dismiss
    @State private var exportItem: ShareItem?
    @State private var selectedYear: Int?

    private var stats: DiaryStatistics { DiaryStatistics.compute(from: entries) }
    private var moodTrend: [MoodTrends.MonthPoint] {
        MoodTrends.monthlyValence(entries, calendar: Calendar(identifier: .gregorian))
    }

    private let gregorian = Calendar(identifier: .gregorian)
    private var availableYears: [Int] {
        Set(entries.map { gregorian.component(.year, from: $0.diaryDate) }).sorted(by: >)
    }
    private var reviewYear: Int {
        // Ignore a stale pick whose entries were all deleted, so the card/export
        // never render an empty year while others still have data.
        if let y = selectedYear, availableYears.contains(y) { return y }
        return availableYears.first ?? gregorian.component(.year, from: Date())
    }
    private var yearReview: YearReview {
        YearReview.build(from: entries, year: reviewYear, calendar: gregorian)
    }

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
            .sheet(item: $exportItem) { ShareSheet(items: [$0.url]) }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.bar.xaxis").scaledFont(30).foregroundStyle(.tertiary)
            Text("还没有可统计的数据").scaledFont(15).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                tiles
                weekSection
                heatmapSection
                milestoneSection
                recapSection
                if !stats.moods.isEmpty { moodSection }
                if !keywords.isEmpty { keywordSection }
                if moodTrend.count >= 2 { moodTrendSection }
                if stats.months.count > 1 { monthSection }
                mediaSection
                if !entries.isEmpty { yearReviewSection }
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

    // MARK: 本周写作 (writing habit — evolution)

    private var weekSection: some View {
        let days = WritingHabit.recentDays(entries, count: 7, calendar: Calendar(identifier: .gregorian))
        return VStack(alignment: .leading, spacing: 12) {
            sectionHeader("本周写作")
            HStack(spacing: 0) {
                ForEach(days, id: \.date) { day in
                    VStack(spacing: 8) {
                        Text(DiaryDateFormat.weekdayShort(day.date))
                            .scaledFont(12).foregroundStyle(.secondary)
                        ZStack {
                            Circle()
                                .fill(day.written ? Color.accentColor : Color(uiColor: .tertiarySystemFill))
                                .frame(width: 30, height: 30)
                            if day.written {
                                Image(systemName: "checkmark").scaledFont(12, weight: .bold)
                                    .foregroundStyle(.white)
                            } else {
                                Text(DiaryDateFormat.dayNumber(day.date))
                                    .scaledFont(12).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .cardBackgroundStyle()
        }
    }

    // MARK: 写作热力图 (evolution — GitHub-style contribution grid)

    private var heatmapSection: some View {
        let columns = WritingHeatmap.columns(from: entries, calendar: gregorian)
        let written = WritingHeatmap.writtenDays(in: columns)
        return VStack(alignment: .leading, spacing: 12) {
            sectionHeader("写作热力图")
            VStack(alignment: .leading, spacing: 10) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 3) {
                        ForEach(Array(columns.enumerated()), id: \.offset) { _, week in
                            VStack(spacing: 3) {
                                ForEach(week) { cell in
                                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                                        .fill(heatColor(cell))
                                        .frame(width: 11, height: 11)
                                }
                            }
                        }
                    }
                }
                .defaultScrollAnchor(.trailing) // newest weeks in view first
                HStack(spacing: 6) {
                    Text("过去一年记录了 \(written) 天").scaledFont(12).foregroundStyle(.secondary)
                    Spacer()
                    Text("少").scaledFont(11).foregroundStyle(.tertiary)
                    ForEach(0..<5) { level in
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(levelColor(level))
                            .frame(width: 11, height: 11)
                    }
                    Text("多").scaledFont(11).foregroundStyle(.tertiary)
                }
            }
            .cardBackgroundStyle()
        }
    }

    private func heatColor(_ cell: WritingHeatmap.Cell) -> Color {
        cell.isFuture ? Color.clear : levelColor(cell.level)
    }

    private func levelColor(_ level: Int) -> Color {
        switch level {
        case 0:  return Color(uiColor: .tertiarySystemFill)
        case 1:  return Color.accentColor.opacity(0.30)
        case 2:  return Color.accentColor.opacity(0.50)
        case 3:  return Color.accentColor.opacity(0.75)
        default: return Color.accentColor
        }
    }

    // MARK: Streak milestones (回顾)

    private var milestoneSection: some View {
        let next = Memories.nextMilestone(currentStreak: stats.currentStreak)
        let achieved = Memories.achievedMilestones(longestStreak: stats.longestStreak)
        return VStack(alignment: .leading, spacing: 12) {
            sectionHeader("连续打卡里程碑")
            VStack(alignment: .leading, spacing: 12) {
                if let next {
                    let progress = min(1, Double(stats.currentStreak) / Double(next))
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("距下一个里程碑").scaledFont(13).foregroundStyle(.secondary)
                            Spacer()
                            Text("\(stats.currentStreak)/\(next) 天").scaledFont(13)
                                .monospacedDigit().foregroundStyle(.secondary)
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color(uiColor: .tertiarySystemFill))
                                Capsule().fill(Color.accentColor)
                                    .frame(width: max(6, geo.size.width * progress))
                            }
                        }
                        .frame(height: 10)
                    }
                } else {
                    Text("已达成全部里程碑 🎉").scaledFont(15).foregroundStyle(.secondary)
                }
                HStack(spacing: 8) {
                    ForEach(Memories.milestones, id: \.self) { m in
                        let got = achieved.contains(m)
                        Text("\(m)天")
                            .scaledFont(12, weight: .semibold)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(got ? Color.accentColor.opacity(0.15) : Color(uiColor: .tertiarySystemFill), in: Capsule())
                            .foregroundStyle(got ? Color.accentColor : Color.secondary)
                    }
                }
            }
            .cardBackgroundStyle()
        }
    }

    // MARK: Monthly recap (回顾, exportable long image)

    @ViewBuilder
    private var recapSection: some View {
        let recap = MonthlyRecap.build(from: entries, month: Date())
        if !recap.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("本月回顾")
                RecapCard(recap: recap)
                Button {
                    if let url = DiaryExporter.exportRecap(recap) { exportItem = ShareItem(url: url) }
                } label: {
                    Label("导出长图", systemImage: "square.and.arrow.up").scaledFont(13)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
                .accessibilityIdentifier("stats.exportRecap")
            }
        }
    }

    // MARK: 情绪趋势 (Swift Charts — evolution)

    private var moodTrendSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("情绪趋势")
            VStack(alignment: .leading, spacing: 8) {
                Chart(moodTrend) { p in
                    AreaMark(x: .value("月份", p.month, unit: .month),
                             y: .value("心情", p.average))
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(LinearGradient(
                            colors: [Color.accentColor.opacity(0.30), Color.accentColor.opacity(0.02)],
                            startPoint: .top, endPoint: .bottom))
                    LineMark(x: .value("月份", p.month, unit: .month),
                             y: .value("心情", p.average))
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(Color.accentColor)
                    PointMark(x: .value("月份", p.month, unit: .month),
                              y: .value("心情", p.average))
                        .foregroundStyle(Color.accentColor)
                }
                .chartYScale(domain: MoodTrends.domain)
                .chartYAxis {
                    AxisMarks(values: [-2.0, -1, 0, 1, 2]) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let d = value.as(Double.self) {
                                Text(MoodTrends.face(forValence: Int(d))).scaledFont(13)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month(.narrow))
                    }
                }
                .frame(height: 170)
                Text("按月平均心情（😊 明亮 → 😢 低落）")
                    .scaledFont(12).foregroundStyle(.secondary)
            }
            .cardBackgroundStyle()
        }
    }

    // MARK: Mood distribution

    // MARK: 关键词洞察 (evolution). Private entries excluded so a distinctive word
    // never leaks out of a locked diary.
    private var keywords: [KeywordInsights.WordCount] {
        KeywordInsights.topWords(from: entries.filter { !$0.isPrivate }, limit: 10)
    }

    private var keywordSection: some View {
        let maxCount = keywords.map(\.count).max() ?? 1
        return VStack(alignment: .leading, spacing: 12) {
            sectionHeader("关键词")
            VStack(spacing: 10) {
                ForEach(keywords) { kw in
                    HStack(spacing: 10) {
                        Text(kw.word).scaledFont(14)
                            .lineLimit(1).frame(width: 88, alignment: .leading)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color(uiColor: .tertiarySystemFill))
                                Capsule().fill(Color.accentColor)
                                    .frame(width: max(6, geo.size.width * CGFloat(kw.count) / CGFloat(maxCount)))
                            }
                        }
                        .frame(height: 10)
                        Text("\(kw.count)").scaledFont(13).monospacedDigit()
                            .foregroundStyle(.secondary).frame(width: 28, alignment: .trailing)
                    }
                }
            }
            .cardBackgroundStyle()
        }
    }

    private var moodSection: some View {
        let maxCount = stats.moods.map(\.count).max() ?? 1
        return VStack(alignment: .leading, spacing: 12) {
            sectionHeader("心情分布")
            VStack(spacing: 10) {
                ForEach(stats.moods) { mood in
                    HStack(spacing: 10) {
                        Text(mood.emoji).scaledFont(20).frame(width: 26)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color(uiColor: .tertiarySystemFill))
                                Capsule().fill(Color.accentColor)
                                    .frame(width: max(6, geo.size.width * CGFloat(mood.count) / CGFloat(maxCount)))
                            }
                        }
                        .frame(height: 10)
                        Text("\(mood.count)").scaledFont(13).monospacedDigit()
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
                        Text("\(month.count)").scaledFont(13).monospacedDigit().foregroundStyle(.secondary)
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Color.accentColor.opacity(0.85))
                            .frame(height: max(6, 90 * CGFloat(month.count) / CGFloat(maxCount)))
                        Text(month.key.replacingOccurrences(of: "年", with: "/").replacingOccurrences(of: "月", with: ""))
                            .scaledFont(10).foregroundStyle(.tertiary)
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
            Image(systemName: system).scaledFont(15).foregroundStyle(Color.accentColor)
            Text("\(count)").scaledFont(17, weight: .semibold).monospacedDigit()
            Text(label).scaledFont(13).foregroundStyle(.secondary)
            Spacer()
        }
        .cardBackgroundStyle()
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text).scaledFont(13, weight: .medium).foregroundStyle(.secondary)
    }

    // MARK: 年度报告 · Year in Review (evolution)

    private var yearReviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionHeader("年度报告")
                Spacer()
                if availableYears.count > 1 {
                    Menu {
                        ForEach(availableYears, id: \.self) { y in
                            Button("\(String(y)) 年") { selectedYear = y }
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Text("\(String(reviewYear)) 年").scaledFont(14, weight: .medium)
                            Image(systemName: "chevron.up.chevron.down").scaledFont(11)
                        }
                        .foregroundStyle(Color.accentColor)
                    }
                    .accessibilityIdentifier("stats.yearPicker")
                }
            }
            YearReviewCard(review: yearReview)
            Button {
                if let url = DiaryExporter.exportYearReview(yearReview) { exportItem = ShareItem(url: url) }
            } label: {
                Label("导出年度报告长图", systemImage: "square.and.arrow.up").scaledFont(13)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.accentColor)
            .accessibilityIdentifier("stats.exportYearReview")
        }
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
                    .scaledFont(30, weight: .bold)
                    .foregroundStyle(accent ? Color.accentColor : .primary)
                    .monospacedDigit()
                if !unit.isEmpty {
                    Text(unit).scaledFont(13).foregroundStyle(.secondary)
                }
            }
            Text(title).scaledFont(13).foregroundStyle(.secondary)
            if let footnote {
                Text(footnote).scaledFont(11).foregroundStyle(.tertiary)
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
