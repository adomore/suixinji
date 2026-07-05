import SwiftUI

/// 组合筛选 sheet (evolution). Pick any-of moods / any-of tags / require media,
/// editing a `DiaryFilter` binding. Presented from Home's filter button.
struct FilterSheet: View {
    @Binding var filter: DiaryFilter
    let availableTags: [String]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("心情") {
                    chipRow(DiaryCatalog.moods, isOn: { filter.moods.contains($0) }, label: { $0 }) {
                        toggle(&filter.moods, $0)
                    }
                }
                if !availableTags.isEmpty {
                    Section("标签") {
                        chipRow(availableTags, isOn: { filter.tags.contains($0) }, label: { "#\($0)" }) {
                            toggle(&filter.tags, $0)
                        }
                    }
                }
                Section("内容") {
                    Toggle("含图片", isOn: $filter.requirePhoto)
                    Toggle("含录音", isOn: $filter.requireAudio)
                }
            }
            .navigationTitle("筛选")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("清除") { filter = DiaryFilter() }
                        .disabled(!filter.isActive)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }.fontWeight(.semibold)
                }
            }
        }
    }

    private func toggle(_ set: inout Set<String>, _ value: String) {
        if set.contains(value) { set.remove(value) } else { set.insert(value) }
    }

    private func chipRow(_ items: [String], isOn: @escaping (String) -> Bool,
                         label: @escaping (String) -> String,
                         tap: @escaping (String) -> Void) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(items, id: \.self) { item in
                    let on = isOn(item)
                    Button { tap(item) } label: {
                        Text(label(item))
                            .scaledFont(15)
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .background(on ? Color.accentColor : Color(uiColor: .tertiarySystemFill),
                                        in: Capsule())
                            .foregroundStyle(on ? Color.white : Color.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }
}
