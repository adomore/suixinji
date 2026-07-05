import SwiftUI
import SwiftData

/// Month calendar (F9): dots mark days that have entries; tapping a day lists
/// that day's entries, and tapping one opens its detail page.
struct CalendarView: View {
    @Query(sort: [SortDescriptor(\DiaryEntry.createdAt, order: .reverse)])
    private var entries: [DiaryEntry]

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var privacy: PrivacyManager

    @State private var visibleMonth: Date = Date()
    @State private var selectedDay: Date = Date()

    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.locale = Locale(identifier: "zh_CN")
        c.firstWeekday = 2 // Monday
        return c
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                monthHeader
                weekdayHeader
                monthGrid
                Divider().padding(.horizontal, Layout.pageMargin)
                dayEntries
                Spacer(minLength: 0)
            }
            .padding(.top, 8)
            .navigationTitle("日历")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("完成") { dismiss() } }
            }
            .navigationDestination(for: DiaryEntry.self) { DetailView(entry: $0) }
        }
    }

    // MARK: Header

    private var monthHeader: some View {
        HStack {
            Button { shiftMonth(-1) } label: { Image(systemName: "chevron.left") }
            Spacer()
            Text(DiaryDateFormat.yearMonth(visibleMonth)).scaledFont(17, weight: .semibold)
            Spacer()
            Button { shiftMonth(1) } label: { Image(systemName: "chevron.right") }
        }
        .padding(.horizontal, Layout.pageMargin)
    }

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(["一", "二", "三", "四", "五", "六", "日"], id: \.self) { d in
                Text(d).scaledFont(13).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, Layout.pageMargin)
    }

    // MARK: Grid

    private var monthGrid: some View {
        let days = monthDays()
        let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
        return LazyVGrid(columns: columns, spacing: 6) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                if let day {
                    dayCell(day)
                } else {
                    Color.clear.frame(height: 44)
                }
            }
        }
        .padding(.horizontal, Layout.pageMargin)
    }

    private func dayCell(_ day: Date) -> some View {
        let isSelected = calendar.isDate(day, inSameDayAs: selectedDay)
        let isToday = calendar.isDateInToday(day)
        let hasEntry = daysWithEntries.contains(dayKey(day))
        return Button {
            selectedDay = day
        } label: {
            VStack(spacing: 3) {
                Text("\(calendar.component(.day, from: day))")
                    .scaledFont(15, weight: isToday ? .semibold : .regular)
                    .foregroundStyle(isSelected ? Color.white : (isToday ? Color.accentColor : Color.primary))
                Circle()
                    .fill(hasEntry ? Color.accentColor : Color.clear)
                    .frame(width: 5, height: 5)
                    .opacity(isSelected ? 0 : 1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                isSelected ? Color.accentColor : Color.clear,
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: Selected-day list

    private var dayEntries: some View {
        let items = entries.filter { calendar.isDate($0.diaryDate, inSameDayAs: selectedDay) }
        return ScrollView {
            if items.isEmpty {
                Text("这天还没有日记")
                    .scaledFont(15).foregroundStyle(.secondary)
                    .padding(.top, 20)
            } else {
                VStack(spacing: Layout.cardGap) {
                    ForEach(items) { entry in
                        if privacy.isHidden(entry) {
                            Button { Task { await privacy.reveal() } } label: {
                                DiaryCardView(entry: entry, redacted: true)
                            }
                            .buttonStyle(.plain)
                        } else {
                            NavigationLink(value: entry) { DiaryCardView(entry: entry) }
                                .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, Layout.pageMargin)
                .padding(.top, 4)
            }
        }
    }

    // MARK: Data

    private var daysWithEntries: Set<String> {
        Set(entries.map { dayKey($0.diaryDate) })
    }

    private func dayKey(_ date: Date) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(c.year!)-\(c.month!)-\(c.day!)"
    }

    /// Days of `visibleMonth` laid out on a Monday-first grid (leading nils pad
    /// the first week).
    private func monthDays() -> [Date?] {
        guard
            let interval = calendar.dateInterval(of: .month, for: visibleMonth),
            let range = calendar.range(of: .day, in: .month, for: visibleMonth)
        else { return [] }
        let first = interval.start
        let weekday = calendar.component(.weekday, from: first) // 1=Sun…7=Sat
        let leading = (weekday - calendar.firstWeekday + 7) % 7
        var cells: [Date?] = Array(repeating: nil, count: leading)
        for day in range {
            cells.append(calendar.date(byAdding: .day, value: day - 1, to: first))
        }
        return cells
    }

    private func shiftMonth(_ delta: Int) {
        if let d = calendar.date(byAdding: .month, value: delta, to: visibleMonth) {
            visibleMonth = d
        }
    }
}
