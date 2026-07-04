import SwiftUI
import SwiftData

/// Home · timeline (UI Brief §4 ①). No TabBar — this is the app's root.
/// Shows entries grouped by "year-month"; a floating ➕ opens the editor sheet;
/// the gear opens Settings; tapping a card pushes the detail page.
struct HomeView: View {
    @Environment(\.modelContext) private var context
    // Sorted for the timeline: newest diary-date first (createdAt is kept on the
    // model for robust ordering per PRD §9, used as the tie-breaker).
    @Query(sort: [SortDescriptor(\DiaryEntry.diaryDate, order: .reverse),
                  SortDescriptor(\DiaryEntry.createdAt, order: .reverse)])
    private var entries: [DiaryEntry]

    @State private var showingEditor = false

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
                    } else {
                        timeline
                    }
                }

                floatingAddButton
            }
            .navigationTitle("随心记")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink { SettingsView() } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 18, weight: .regular))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationDestination(for: DiaryEntry.self) { entry in
                DetailView(entry: entry)
            }
        }
        .sheet(isPresented: $showingEditor) {
            EditorView(mode: .create)
        }
    }

    private var timeline: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: []) {
                ForEach(groupedSections, id: \.key) { section in
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
                        }
                    }
                    .padding(.horizontal, Layout.pageMargin)
                }
            }
            .padding(.bottom, 120) // clear the floating button
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
                        .shadow(color: Color.brand.opacity(0.35), radius: 8, x: 0, y: 2)
                }
                .padding(.trailing, Layout.fabTrailing)
                .padding(.bottom, Layout.fabBottom)
            }
        }
    }

    // MARK: Grouping

    private struct Section: Identifiable {
        let key: String        // "2026年7月"
        let entries: [DiaryEntry]
        var id: String { key }
    }

    /// Preserve the query order and split into contiguous year-month runs.
    private var groupedSections: [Section] {
        var result: [Section] = []
        var currentKey: String? = nil
        var bucket: [DiaryEntry] = []
        for entry in entries {
            let key = DiaryDateFormat.yearMonth(entry.diaryDate)
            if key != currentKey {
                if let ck = currentKey { result.append(Section(key: ck, entries: bucket)) }
                currentKey = key
                bucket = [entry]
            } else {
                bucket.append(entry)
            }
        }
        if let ck = currentKey { result.append(Section(key: ck, entries: bucket)) }
        return result
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
