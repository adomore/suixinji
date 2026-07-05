import SwiftUI
import SwiftData

/// Home · timeline (UI Brief §4 ①). No TabBar — this is the app's root.
/// Shows entries grouped by "year-month"; a floating ➕ opens the editor sheet;
/// the gear opens Settings; tapping a card pushes the detail page.
struct HomeView: View {
    @Environment(\.modelContext) private var context
    // Ordered newest-first by `createdAt` (PRD §9: sort by createdAt so a changed
    // system clock can't reshuffle the timeline; the *displayed* date is diaryDate).
    // Section headers still group by diaryDate's year-month.
    @Query(sort: [SortDescriptor(\DiaryEntry.createdAt, order: .reverse)])
    private var entries: [DiaryEntry]

    @EnvironmentObject private var router: AppRouter
    @State private var path: [DiaryEntry] = []

    @State private var showingEditor = false
    @State private var showingCalendar = false
    @State private var showingStats = false
    @State private var showingMemories = false
    @State private var showingMap = false
    @State private var showingFilter = false
    @State private var filter = DiaryFilter()
    @State private var searchText = ""

    /// Entries after applying the combined filter (evolution) then keyword search (F8).
    private var filteredEntries: [DiaryEntry] {
        DiarySearch.filter(filter.apply(to: entries), query: searchText)
    }

    /// Earlier-year entries sharing today's date (回顾 · 这一天).
    private var onThisDay: [DiaryEntry] {
        Memories.onThisDay(entries, today: Date(), calendar: Calendar(identifier: .gregorian))
    }

    /// 每日灵感: has the user written anything dated today yet?
    private var writtenToday: Bool {
        entries.contains { Calendar.current.isDateInToday($0.diaryDate) }
    }
    private var todayPrompt: String { WritingPrompts.ofTheDay() }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                Color.pageBackground.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 0) {
                    // Today's date, directly under the large title (matches mock 1a / 2c).
                    Text(DiaryDateFormat.longChinese(Date()))
                        .scaledFont(15)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, Layout.pageMargin)
                        .padding(.top, 4)

                    if !onThisDay.isEmpty && searchText.isEmpty {
                        onThisDayBanner
                    }

                    if !writtenToday && searchText.isEmpty {
                        promptBanner
                    }

                    if filter.isActive {
                        activeFilterBar
                    }

                    if entries.isEmpty {
                        EmptyStateView()
                    } else if filteredEntries.isEmpty {
                        noSearchResults
                    } else {
                        timeline
                    }
                }

                floatingAddButton
            }
            .navigationTitle("随心记")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "搜索日记")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showingCalendar = true } label: {
                        Image(systemName: "calendar")
                            .scaledFont(17, weight: .regular)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("日历")
                    .accessibilityIdentifier("nav.calendar")
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button { showingMap = true } label: {
                        Image(systemName: "map")
                            .scaledFont(17, weight: .regular)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("足迹地图")
                    .accessibilityIdentifier("nav.map")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingFilter = true } label: {
                        Image(systemName: filter.isActive ? "line.3.horizontal.decrease.circle.fill"
                                                           : "line.3.horizontal.decrease.circle")
                            .scaledFont(17, weight: .regular)
                            .foregroundStyle(filter.isActive ? Color.accentColor : .secondary)
                    }
                    .accessibilityLabel("筛选")
                    .accessibilityIdentifier("nav.filter")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingStats = true } label: {
                        Image(systemName: "chart.bar.xaxis")
                            .scaledFont(17, weight: .regular)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("统计")
                    .accessibilityIdentifier("nav.stats")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink { SettingsView() } label: {
                        Image(systemName: "gearshape")
                            .scaledFont(18, weight: .regular)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("设置")
                    .accessibilityIdentifier("nav.settings")
                }
            }
            .navigationDestination(for: DiaryEntry.self) { entry in
                DetailView(entry: entry)
            }
        }
        .sheet(isPresented: $showingEditor) {
            EditorView(mode: .create, promptPlaceholder: todayPrompt).themedRoot()
        }
        .sheet(isPresented: $showingCalendar) {
            CalendarView().themedRoot()
        }
        .sheet(isPresented: $showingStats) {
            StatisticsView().themedRoot()
        }
        .sheet(isPresented: $showingMap) {
            MapView().themedRoot()
        }
        .sheet(isPresented: $showingFilter) {
            FilterSheet(filter: $filter, availableTags: TagManager.tagCounts(entries).map(\.tag))
                .themedRoot()
        }
        .sheet(isPresented: $showingMemories) {
            MemoriesListView(entries: onThisDay, today: Date()).themedRoot()
        }
        // Keep the home-screen widget's snapshot fresh after any change (evolution).
        .task { publishWidgetSnapshot(entries) }
        .onChange(of: entries) { _, list in
            publishWidgetSnapshot(list)
            openPendingEntry() // a deep-linked entry may have just loaded
        }
        // Spotlight: rebuild the index once on launch; deep-link taps navigate.
        .task {
            SpotlightIndexer.reindexAll(entries)
            openPendingEntry()
        }
        .onChange(of: router.pendingEntryID) { _, _ in openPendingEntry() }
    }

    /// Navigate to the entry a Spotlight deep link requested, if it's present.
    private func openPendingEntry() {
        guard let id = router.pendingEntryID,
              let entry = entries.first(where: { $0.id == id }) else { return }
        path = [entry]
        router.pendingEntryID = nil
    }

    private func publishWidgetSnapshot(_ list: [DiaryEntry]) {
        let stats = DiaryStatistics.compute(from: list)
        let cal = Calendar.current
        let wroteToday = list.contains { cal.isDateInToday($0.diaryDate) }
        SharedStore.write(WidgetSnapshot(
            currentStreak: stats.currentStreak,
            totalEntries: stats.totalEntries,
            wroteToday: wroteToday,
            generatedAt: Date()
        ))
    }

    // "N 年前的今天" banner leading the eye to past memories (回顾).
    private var onThisDayBanner: some View {
        Button { showingMemories = true } label: {
            HStack(spacing: 10) {
                Image(systemName: "sparkles").scaledFont(15).foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 1) {
                    Text("这一天").scaledFont(15, weight: .semibold).foregroundStyle(.primary)
                    Text(memoriesSubtitle).scaledFont(13).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").scaledFont(12, weight: .semibold)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(Color.accentColor.opacity(0.10), in: RoundedRectangle(cornerRadius: Layout.cardRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Layout.pageMargin)
        .padding(.top, 12)
        .accessibilityIdentifier("home.memories")
    }

    /// 每日灵感 nudge — the day's prompt; tapping opens the editor (prompt shown
    /// as its placeholder). Only appears when nothing's been written today.
    private var promptBanner: some View {
        Button { showingEditor = true } label: {
            HStack(spacing: 10) {
                Image(systemName: "lightbulb").scaledFont(15).foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 1) {
                    Text("今日灵感").scaledFont(13, weight: .semibold).foregroundStyle(.secondary)
                    Text(todayPrompt).scaledFont(15).foregroundStyle(.primary)
                        .multilineTextAlignment(.leading).lineLimit(2)
                }
                Spacer(minLength: 6)
                Image(systemName: "square.and.pencil").scaledFont(14, weight: .semibold)
                    .foregroundStyle(Color.accentColor)
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: Layout.cardRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Layout.pageMargin)
        .padding(.top, 12)
        .accessibilityIdentifier("home.prompt")
    }

    private var memoriesSubtitle: String {
        let cal = Calendar(identifier: .gregorian)
        if let latest = onThisDay.first {
            let years = Memories.yearsAgo(latest.diaryDate, from: Date(), calendar: cal)
            let more = onThisDay.count > 1 ? " · 共 \(onThisDay.count) 篇" : ""
            return "\(years) 年前的今天\(more)"
        }
        return "回顾过往"
    }

    private var noSearchResults: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "magnifyingglass").scaledFont(28).foregroundStyle(.tertiary)
            Text(filter.isActive ? "没有符合条件的日记" : "没有找到相关日记")
                .scaledFont(15).foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    /// A slim bar shown while a combined filter is active, with a one-tap clear.
    private var activeFilterBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "line.3.horizontal.decrease.circle.fill")
                .scaledFont(13).foregroundStyle(Color.accentColor)
            Text("筛选中 · \(filter.activeCount) 项").scaledFont(13).foregroundStyle(.secondary)
            Spacer()
            Button("清除") { filter = DiaryFilter() }
                .scaledFont(13).foregroundStyle(Color.accentColor)
                .accessibilityIdentifier("home.clearFilter")
        }
        .padding(.horizontal, Layout.pageMargin)
        .padding(.top, 10)
    }

    private var timeline: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: []) {
                ForEach(groupedSections) { section in
                    Text(section.key)
                        .scaledFont(13, weight: .medium)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, Layout.pageMargin)
                        .padding(.top, 26)
                        .padding(.bottom, 10)

                    VStack(spacing: Layout.cardGap) {
                        ForEach(section.entries) { entry in
                            NavigationLink(value: entry) {
                                DiaryCardView(entry: entry)
                            }
                            .buttonStyle(.plain)
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }
                    }
                    .padding(.horizontal, Layout.pageMargin)
                }
            }
            .padding(.bottom, 120) // clear the floating button
            // Brief §6.1: a newly-saved card drops into the top with a light
            // insert animation (~0.3s) for the "记下来了" confirmation feel.
            .animation(.smooth(duration: 0.3), value: entries.map(\.id))
        }
    }

    private var floatingAddButton: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button {
                    showingEditor = true
                } label: {
                    Image(systemName: "plus")
                        .scaledFont(24, weight: .semibold)
                        .foregroundStyle(.white)
                        .frame(width: Layout.fabDiameter, height: Layout.fabDiameter)
                        .background(Color.accentColor, in: Circle())
                        // Brief §4①: light shadow, y=2 blur=8 opacity ≤15%.
                        .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 2)
                }
                .accessibilityLabel("新建日记")
                .accessibilityIdentifier("fab.add")
                .padding(.trailing, Layout.fabTrailing)
                .padding(.bottom, Layout.fabBottom)
            }
        }
    }

    // MARK: Grouping (pure logic lives in DiaryTimeline for unit-testing)

    private var groupedSections: [DiaryTimeline.Section] {
        DiaryTimeline.sections(from: filteredEntries)
    }
}

/// Empty state (UI Brief §5). One line of guidance + a minimal waveform mark;
/// a dashed curved arrow leads the eye to the ➕. No big illustration.
private struct EmptyStateView: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                VStack(spacing: 12) {
                    HStack(alignment: .bottom, spacing: 3) {
                        bar(0.55, 10); bar(0.75, 18); bar(1, 13); bar(0.75, 22); bar(0.55, 9)
                    }
                    Text("记录今天的第一条心情吧")
                        .scaledFont(17)
                        .foregroundStyle(.secondary)
                }
                .position(x: geo.size.width / 2, y: geo.size.height * 0.44)

                // Dashed curve from center-ish down to the ➕ at bottom-trailing.
                GuidingArrow()
                    .stroke(style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [5, 6]))
                    .foregroundStyle(Color(uiColor: .separator))
                    .frame(width: 120, height: 180)
                    .position(x: geo.size.width - 52 - 60, y: geo.size.height - 116 - 90)
            }
        }
    }

    private func bar(_ opacity: Double, _ h: CGFloat) -> some View {
        Capsule().fill(Color.accentColor.opacity(opacity)).frame(width: 3, height: h)
    }
}

/// A gentle S-curve with an arrowhead, pointing toward the floating ➕.
private struct GuidingArrow: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 18, y: 14))
        p.addCurve(to: CGPoint(x: 100, y: 156),
                   control1: CGPoint(x: 66, y: 44),
                   control2: CGPoint(x: 96, y: 88))
        // arrowhead
        p.move(to: CGPoint(x: 91, y: 143))
        p.addLine(to: CGPoint(x: 100, y: 158))
        p.addLine(to: CGPoint(x: 111, y: 147))
        return p
    }
}

#Preview {
    HomeView()
        .modelContainer(for: DiaryEntry.self, inMemory: true)
        .environmentObject(AppRouter())
        .tint(.brand)
}
