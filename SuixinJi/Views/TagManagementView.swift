import SwiftUI
import SwiftData

/// 标签管理 (evolution). List all tags with usage counts; rename (rename-onto-an-
/// existing-tag merges) or delete across every entry. Pushed from Settings.
struct TagManagementView: View {
    @Environment(\.modelContext) private var context
    @Query private var entries: [DiaryEntry]

    @State private var renameTarget: String?
    @State private var renameText = ""
    @State private var deleteTarget: String?

    private var tags: [TagManager.TagCount] { TagManager.tagCounts(entries) }

    var body: some View {
        Group {
            if tags.isEmpty {
                ContentUnavailableView("还没有标签", systemImage: "tag",
                                       description: Text("写日记时添加标签，就能在这里管理。"))
            } else {
                List {
                    Section {
                        ForEach(tags) { tc in
                            HStack {
                                Text("#\(tc.tag)").scaledFont(16)
                                Spacer()
                                Text("\(tc.count)").scaledFont(14).monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) { deleteTarget = tc.tag } label: {
                                    Label("删除", systemImage: "trash")
                                }
                                Button { startRename(tc.tag) } label: {
                                    Label("重命名", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                        }
                    } footer: {
                        Text("左滑重命名或删除。重命名为已有标签会合并两者。")
                    }
                }
            }
        }
        .navigationTitle("标签管理")
        .navigationBarTitleDisplayMode(.inline)
        .alert("重命名标签", isPresented: Binding(
            get: { renameTarget != nil }, set: { if !$0 { renameTarget = nil } }
        )) {
            TextField("标签名", text: $renameText)
            Button("取消", role: .cancel) {}
            Button("保存") {
                if let from = renameTarget {
                    TagManager.rename(from: from, to: renameText, in: entries, context: context)
                }
            }
        } message: {
            Text("重命名为已有标签会把两者合并。")
        }
        .alert("删除标签", isPresented: Binding(
            get: { deleteTarget != nil }, set: { if !$0 { deleteTarget = nil } }
        ), presenting: deleteTarget) { tag in
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                TagManager.delete(tag: tag, in: entries, context: context)
            }
        } message: { tag in
            Text("将从所有日记中移除「\(tag)」标签，日记本身不受影响。")
        }
    }

    private func startRename(_ tag: String) {
        renameText = tag
        renameTarget = tag
    }
}
