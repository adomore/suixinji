import WidgetKit
import SwiftUI
import AppIntents

// `Color.brand` is defined file-private in each widget source (the design system's
// copy lives in the app target only), so mirror it here.
private extension Color {
    static let brand = Color(red: 255 / 255, green: 138 / 255, blue: 92 / 255)
}

/// 快速心情打卡 (evolution). A Home Screen widget with tappable mood emojis. On
/// iOS 18 each mood is an interactive `Button(intent:)` that records the check-in
/// silently (see `MoodCheckInIntent`); the app materializes it into a diary entry
/// on next launch. Older systems fall back to a non-interactive prompt.
struct MoodCheckInEntry: TimelineEntry {
    let date: Date
    let last: MoodInbox.PendingMood?
}

struct MoodCheckInProvider: TimelineProvider {
    func placeholder(in context: Context) -> MoodCheckInEntry {
        MoodCheckInEntry(date: Date(), last: nil)
    }
    func getSnapshot(in context: Context, completion: @escaping (MoodCheckInEntry) -> Void) {
        completion(MoodCheckInEntry(date: Date(), last: MoodInbox.last()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<MoodCheckInEntry>) -> Void) {
        let entry = MoodCheckInEntry(date: Date(), last: MoodInbox.last())
        // Refresh near the next midnight so the "today" state resets.
        let next = Calendar.current.nextDate(after: Date(), matching: DateComponents(hour: 0, minute: 1),
                                             matchingPolicy: .nextTime) ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct MoodCheckInWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SuixinJiMoodCheckIn", provider: MoodCheckInProvider()) { entry in
            MoodCheckInWidgetView(entry: entry)
        }
        .configurationDisplayName("心情打卡")
        .description("在主屏一键记录当下的心情。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct MoodCheckInWidgetView: View {
    let entry: MoodCheckInEntry
    @Environment(\.widgetFamily) private var family

    /// The moods offered on the widget (a compact subset that fits the small size).
    private let moods = ["😊", "🙂", "😐", "😔", "😢", "😴"]

    private var checkedInToday: Bool {
        guard let last = entry.last else { return false }
        return Calendar.current.isDateInToday(last.date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("今天心情如何？")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if checkedInToday, let last = entry.last {
                    Text(last.mood).font(.title3)
                }
            }
            .foregroundStyle(.primary)

            if checkedInToday {
                Text("已记录，点按可更改")
                    .font(.caption).foregroundStyle(.secondary)
            }

            moodRow
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(.background, for: .widget)
    }

    @ViewBuilder
    private var moodRow: some View {
        let shown = family == .systemSmall ? Array(moods.prefix(4)) : moods
        HStack(spacing: family == .systemSmall ? 6 : 10) {
            ForEach(shown, id: \.self) { mood in
                moodButton(mood)
            }
        }
    }

    @ViewBuilder
    private func moodButton(_ mood: String) -> some View {
        let selected = checkedInToday && entry.last?.mood == mood
        let label = Text(mood)
            .font(.title2)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(selected ? Color.brand.opacity(0.20) : Color.brand.opacity(0.06),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))

        if #available(iOS 18.0, *) {
            Button(intent: MoodCheckInIntent(mood: mood)) { label }
                .buttonStyle(.plain)
        } else {
            // iOS 17: non-interactive; tapping the widget opens the app to record.
            label
        }
    }
}
