import WidgetKit
import SwiftUI
import AppIntents

// `Color.brand` is file-private in each widget source; mirror it here.
private extension Color {
    static let brand = Color(red: 255 / 255, green: 138 / 255, blue: 92 / 255)
}

/// 今日一句 (evolution). A Home Screen + Lock Screen widget showing the day's writing
/// prompt (the same 每日灵感 line the app's home banner shows). The prompt is pure &
/// date-derived (`WritingPrompts.ofTheDay`, in Shared), so the widget computes it
/// itself and refreshes at midnight. Tapping opens the app to write.
struct DailyQuoteEntry: TimelineEntry {
    let date: Date
    let quote: String
}

struct DailyQuoteProvider: TimelineProvider {
    func placeholder(in context: Context) -> DailyQuoteEntry {
        DailyQuoteEntry(date: Date(), quote: WritingPrompts.all.first ?? "")
    }
    func getSnapshot(in context: Context, completion: @escaping (DailyQuoteEntry) -> Void) {
        completion(DailyQuoteEntry(date: Date(), quote: WritingPrompts.ofTheDay()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<DailyQuoteEntry>) -> Void) {
        let now = Date()
        let entry = DailyQuoteEntry(date: now, quote: WritingPrompts.ofTheDay(now))
        let nextMidnight = Calendar.current.nextDate(after: now, matching: DateComponents(hour: 0, minute: 1),
                                                     matchingPolicy: .nextTime) ?? now.addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(nextMidnight)))
    }
}

struct DailyQuoteWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SuixinJiDailyQuote", provider: DailyQuoteProvider()) { entry in
            DailyQuoteWidgetView(entry: entry)
        }
        .configurationDisplayName("今日一句")
        .description("每天一句温柔的写作灵感。")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

struct DailyQuoteWidgetView: View {
    let entry: DailyQuoteEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryRectangular:
            rectangular
        default:
            home
        }
    }

    // Lock Screen · rectangular
    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label("今日一句", systemImage: "quote.opening")
                .font(.caption2).widgetAccentable()
            Text(entry.quote)
                .font(.caption).lineLimit(3).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .containerBackground(for: .widget) { Color.clear }
    }

    // Home Screen · small / medium — the whole card opens the compose flow.
    private var home: some View {
        Button(intent: QuickAddIntent()) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "quote.opening").font(.caption2)
                    Text("今日一句").font(.caption2).fontWeight(.semibold)
                    Spacer()
                }
                .foregroundStyle(Color.brand)

                Text(entry.quote)
                    .font(family == .systemSmall ? .subheadline : .headline)
                    .fontWeight(.medium)
                    .lineLimit(family == .systemSmall ? 5 : 3)
                    .minimumScaleFactor(0.6)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                HStack(spacing: 4) {
                    Image(systemName: "square.and.pencil").font(.caption2)
                    Text("写下此刻").font(.caption2)
                    Spacer()
                }
                .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .containerBackground(.background, for: .widget)
    }
}
