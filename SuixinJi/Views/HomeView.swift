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

    @State private var showingEditor = false
    @State private var showingCalendar = false
    @State private var searchText = ""

    /// Entries after applying keyword search (F8).
    private var filteredEntries: [DiaryEntry] {
        DiarySearch.filter(entries, query: searchText)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.pageBackground.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 0) {
                    // Today's date, directly under the large title (matches mock 1a / 2c).
                    Text(DiaryDateFormat.longChinese(Date()))
                        .font(.summary15)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, Layout.pageMargin)
                        .padding(.top, 4)

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
                            .font(.system(size: 17, weight: .regular))
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("日历")
                    .accessibilityIdentifier("nav.calendar")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink { SettingsView() } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 18, weight: .regular))
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
            EditorView(mode: .create)
        }
        .sheet(isPresented: $showingCalendar) {
            CalendarView()
        }
    }

    private var noSearchResults: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "magnifyingglass").font(.system(size: 28)).foregroundStyle(.tertiary)
            Text("没有找到相关日记").font(.summary15).foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var timeline: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: []) {
                ForEach(groupedSections) { section in
                    Text(section.key)
                        .font(.groupHeader13)
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
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: Layout.fabDiameter, height: Layout.fabDiameter)
                        .background(Color.brand, in: Circle())
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
                        .font(.body17)
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
        Capsule().fill(Color.brand.opacity(opacity)).frame(width: 3, height: h)
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
        .tint(.brand)
}
