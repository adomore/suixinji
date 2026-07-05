import WidgetKit
import SwiftUI
import AppIntents

/// Signature warm-orange (#FF8A5C) — the widget is a separate target and doesn't
/// share the app's Theme, so the accent is defined locally. (On the Lock Screen,
/// accessory families render tinted/monochrome, so brand color only shows on the
/// Home Screen families.)
private extension Color {
    static let brand = Color(red: 255 / 255, green: 138 / 255, blue: 92 / 255)
}

struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct TodayProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry {
        SnapshotEntry(date: Date(), snapshot: .empty)
    }
    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        completion(SnapshotEntry(date: Date(), snapshot: SharedStore.read()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        let entry = SnapshotEntry(date: Date(), snapshot: SharedStore.read())
        // Refresh a little after the next midnight so "today"/streak stay current.
        let next = Calendar.current.nextDate(
            after: Date(), matching: DateComponents(hour: 0, minute: 5),
            matchingPolicy: .nextTime
        ) ?? Date().addingTimeInterval(6 * 3600)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct TodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SuixinJiToday", provider: TodayProvider()) { entry in
            TodayWidgetView(entry: entry)
        }
        .configurationDisplayName("随心记")
        .description("今天的记录与连续天数。")
        .supportedFamilies([
            .systemSmall, .systemMedium,
            .accessoryInline, .accessoryCircular, .accessoryRectangular
        ])
    }
}

struct TodayWidgetView: View {
    let entry: SnapshotEntry
    @Environment(\.widgetFamily) private var family

    private var streak: Int { entry.snapshot.currentStreak }
    private var wroteToday: Bool { entry.snapshot.wroteToday }

    private var todayString: String {
        let f = DateFormatter()
        f.locale = .current
        if f.locale.language.languageCode == .chinese {
            f.dateFormat = "M月d日 EEEE"
        } else {
            f.setLocalizedDateFormatFromTemplate("EEEMMMd")
        }
        return f.string(from: entry.date)
    }

    var body: some View {
        switch family {
        case .accessoryInline:
            // Lock Screen inline: a single line beside the clock.
            Label(wroteToday ? "连续 \(streak) 天 · 今天已记" : "连续 \(streak) 天 · 待记录",
                  systemImage: "flame.fill")
        case .accessoryCircular:
            circularView
        case .accessoryRectangular:
            rectangularView
        default:
            homeScreenView
        }
    }

    // MARK: Lock Screen · circular

    private var circularView: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Image(systemName: "flame.fill").font(.system(size: 11))
                Text("\(streak)")
                    .font(.system(size: 22, weight: .bold)).minimumScaleFactor(0.5)
                Text("天").font(.system(size: 9)).foregroundStyle(.secondary)
            }
        }
        .containerBackground(for: .widget) { Color.clear }
    }

    // MARK: Lock Screen · rectangular

    private var rectangularView: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label("连续 \(streak) 天", systemImage: "flame.fill")
                .font(.headline).widgetAccentable()
            Text(wroteToday ? "今天已记录 ✓" : "今天还没写")
                .font(.caption)
            Text("累计 \(entry.snapshot.totalEntries) 篇")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .containerBackground(for: .widget) { Color.clear }
    }

    // MARK: Home Screen · small / medium (unchanged design)

    private var homeScreenView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("随心记").font(.caption).fontWeight(.semibold)
                Spacer()
                Text(todayString).font(.caption2).foregroundStyle(.secondary)
            }
            Spacer(minLength: 6)

            HStack(alignment: .bottom, spacing: 12) {
                streakBlock
                if family == .systemMedium {
                    Divider()
                    countBlock
                    Spacer()
                }
            }

            Spacer(minLength: 6)
            composeButton
        }
        .containerBackground(.background, for: .widget)
    }

    private var streakBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(streak)")
                .font(.system(size: 34, weight: .bold)).foregroundStyle(Color.brand)
                .monospacedDigit()
            Text("连续天数").font(.caption2).foregroundStyle(.secondary)
        }
    }

    private var countBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(entry.snapshot.totalEntries)")
                .font(.system(size: 34, weight: .bold)).monospacedDigit()
            Text("累计日记").font(.caption2).foregroundStyle(.secondary)
        }
    }

    private var composeButton: some View {
        Button(intent: QuickAddIntent()) {
            Label(wroteToday ? "今天已记录" : "记录今天",
                  systemImage: wroteToday ? "checkmark.circle" : "square.and.pencil")
                .font(.caption).fontWeight(.medium)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.brand)
    }
}
