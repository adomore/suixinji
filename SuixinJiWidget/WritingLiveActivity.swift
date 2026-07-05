import ActivityKit
import WidgetKit
import SwiftUI

private extension Color {
    static let brand = Color(red: 255 / 255, green: 138 / 255, blue: 92 / 255)
}

/// 写作计时 Live Activity (evolution): Lock Screen banner + Dynamic Island. The
/// elapsed time counts up from `startDate` via `Text(timerInterval:)` — the system
/// advances it every second with no updates from the app.
struct WritingLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WritingActivityAttributes.self) { context in
            // Lock Screen / notification-banner presentation.
            HStack(spacing: 12) {
                Image(systemName: "square.and.pencil")
                    .font(.title2).foregroundStyle(Color.brand)
                VStack(alignment: .leading, spacing: 2) {
                    Text("随心记 · 写作中").font(.subheadline).fontWeight(.semibold)
                    Text("\(context.state.characters) 字").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                timer(context).font(.title3).monospacedDigit().foregroundStyle(Color.brand)
            }
            .padding()
            .activityBackgroundTint(Color.black.opacity(0.25))
            .activitySystemActionForegroundColor(Color.brand)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("写作中", systemImage: "square.and.pencil")
                        .font(.caption).foregroundStyle(Color.brand)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    timer(context).font(.caption).monospacedDigit()
                        .foregroundStyle(Color.brand).frame(maxWidth: 64)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("已写 \(context.state.characters) 字")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            } compactLeading: {
                Image(systemName: "square.and.pencil").foregroundStyle(Color.brand)
            } compactTrailing: {
                timer(context).monospacedDigit().foregroundStyle(Color.brand).frame(maxWidth: 44)
            } minimal: {
                Image(systemName: "square.and.pencil").foregroundStyle(Color.brand)
            }
        }
    }

    /// Count-up stopwatch from the session start (bounded far end for formatting).
    private func timer(_ context: ActivityViewContext<WritingActivityAttributes>) -> Text {
        Text(timerInterval: context.attributes.startDate...context.attributes.startDate.addingTimeInterval(86_400),
             countsDown: false)
    }
}
