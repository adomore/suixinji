import SwiftUI

/// "这一天" — entries from earlier years sharing today's date (evolution).
/// Presented from the home banner; tapping a card opens its detail page.
struct MemoriesListView: View {
    let entries: [DiaryEntry]
    let today: Date

    @Environment(\.dismiss) private var dismiss
    private let calendar = Calendar(identifier: .gregorian)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(entries) { entry in
                        VStack(alignment: .leading, spacing: 8) {
                            Text("\(Memories.yearsAgo(entry.diaryDate, from: today, calendar: calendar)) 年前 · \(DiaryDateFormat.yearMonth(entry.diaryDate))")
                                .font(.groupHeader13)
                                .foregroundStyle(.secondary)
                            NavigationLink(value: entry) { DiaryCardView(entry: entry) }
                                .buttonStyle(.plain)
                        }
                    }
                }
                .padding(Layout.pageMargin)
            }
            .background(Color.pageBackground.ignoresSafeArea())
            .navigationTitle("这一天")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("完成") { dismiss() } }
            }
            .navigationDestination(for: DiaryEntry.self) { DetailView(entry: $0) }
        }
    }
}
