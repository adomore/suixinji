import SwiftUI
import SwiftData

/// Detail page (UI Brief §4 ③), pushed from a timeline card.
/// Order: mood (P1) → playback bar → full text → photo grid (tap → pager).
/// "···" menu offers 编辑 / 删除 (destructive). Delete asks for confirmation and
/// removes the associated files first (PRD §5.3, §9).
struct DetailView: View {
    @Bindable var entry: DiaryEntry

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @StateObject private var player = AudioPlaybackManager()
    @State private var showEditor = false
    @State private var showDeleteConfirm = false
    @State private var viewerIndex: Int?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let mood = entry.mood, !mood.isEmpty {
                    Text(mood).font(.system(size: 34))
                }

                if entry.hasAudio {
                    playbackBar
                }

                if !entry.text.isEmpty {
                    Text(entry.text)
                        .font(.body17)
                        .lineSpacing(4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if !entry.imageFileNames.isEmpty {
                    photoGrid
                }
            }
            .padding(.horizontal, Layout.pageMargin)
            .padding(.top, 16)
            .padding(.bottom, 40)
        }
        .background(Color.pageBackground.ignoresSafeArea())
        .navigationTitle(DiaryDateFormat.longChinese(entry.diaryDate))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { showEditor = true } label: {
                        Label("编辑", systemImage: "pencil")
                    }
                    Button(role: .destructive) { showDeleteConfirm = true } label: {
                        Label("删除", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 18))
                }
            }
        }
        .onAppear(perform: prepareAudio)
        .onDisappear { player.stop() }
        .sheet(isPresented: $showEditor, onDismiss: prepareAudio) {
            EditorView(mode: .edit(entry))
        }
        .fullScreenCover(item: Binding(
            get: { viewerIndex.map { PagerIndex(value: $0) } },
            set: { viewerIndex = $0?.value }
        )) { idx in
            PhotoPagerView(fileNames: entry.imageFileNames, startIndex: idx.value)
        }
        .alert("删除这篇日记？", isPresented: $showDeleteConfirm) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) { deleteEntry() }
        } message: {
            Text("删除后不可恢复，关联的图片和录音也会一并删除。")
        }
    }

    // MARK: Playback bar (▶/⏸ + waveform-as-progress + played/total time)

    private var playbackBar: some View {
        HStack(spacing: 12) {
            Button { player.toggle() } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.brand)
                    .frame(width: 32, height: 32)
            }

            WaveformView(progress: player.progress)
                .frame(height: 24)

            Text("\(DiaryDateFormat.duration(player.currentTime)) / \(DiaryDateFormat.duration(entry.audioDuration ?? player.duration))")
                .font(.aux13)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .frame(height: 56)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Layout.cardRadius, style: .continuous))
    }

    private var photoGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)
        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(Array(entry.imageFileNames.enumerated()), id: \.offset) { idx, name in
                Button { viewerIndex = idx } label: {
                    GeometryReader { geo in
                        Group {
                            if let img = FileStore.shared.loadImage(name) {
                                Image(uiImage: img).resizable().scaledToFill()
                            } else {
                                Color(uiColor: .tertiarySystemFill)
                            }
                        }
                        .frame(width: geo.size.width, height: geo.size.width)
                        .clipShape(RoundedRectangle(cornerRadius: Layout.thumbnailRadius, style: .continuous))
                    }
                    .aspectRatio(1, contentMode: .fit)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Actions

    private func prepareAudio() {
        guard let name = entry.audioFileName else { return }
        player.load(url: FileStore.shared.audioURL(name))
    }

    private func deleteEntry() {
        player.stop()                       // stop before deleting (PRD §9)
        FileStore.shared.deleteFiles(for: entry)   // files first, then the record
        context.delete(entry)
        try? context.save()
        dismiss()
    }
}

/// Wrapper so an `Int` index can drive an `item:`-based fullScreenCover.
private struct PagerIndex: Identifiable {
    let value: Int
    var id: Int { value }
}

#Preview {
    NavigationStack {
        DetailView(entry: DiaryEntry(text: "今天去看了朝霞，云层烧得特别透，等了四十分钟总算没白等。"))
    }
    .modelContainer(for: DiaryEntry.self, inMemory: true)
    .tint(.brand)
}
