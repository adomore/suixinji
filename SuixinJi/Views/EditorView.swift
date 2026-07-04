import SwiftUI
import SwiftData
import PhotosUI

/// Write / edit sheet (UI Brief §4 ②). New and edit share this screen.
/// Covers: text, date pill, photo nine-grid, single recording bar, the glass
/// toolbar (转文字 / 录音 / 图片), the recording-in-progress state, save-disabled,
/// permission guidance, and discard-on-cancel confirmation.
struct EditorView: View {
    enum Mode: Equatable {
        case create
        case edit(DiaryEntry)
    }

    let mode: Mode

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    // Draft state
    @State private var text = ""
    @State private var diaryDate = Date()
    @State private var images: [EditorImage] = []
    @State private var audio: DraftAudio?
    // Metadata (P1/P2): mood / weather / tags / location.
    @State private var mood: String?
    @State private var weather: String?
    @State private var weatherText: String?
    @State private var tags: [String] = []
    @State private var locationName: String?
    @State private var latitude: Double?
    @State private var longitude: Double?

    // Baselines for change-detection (discard confirmation)
    @State private var initialText = ""
    @State private var initialImageCount = 0
    @State private var initialHadAudio = false
    @State private var initialMood: String?
    @State private var initialWeather: String?
    @State private var initialTags: [String] = []
    @State private var initialLocation: String?

    // UI state
    @State private var showDatePicker = false
    @State private var photoSourceDialog = false
    @State private var showPhotoLibrary = false
    @State private var photosPickerItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var showDiscardConfirm = false
    @State private var permissionAlert: PermissionKind?
    @State private var errorMessage: String?

    // Services
    @StateObject private var recorder = AudioRecorder()
    @StateObject private var transcriber = SpeechTranscriber()
    @State private var transcribeBase = ""   // text captured when transcription started

    @FocusState private var editorFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            navRow
            content
            Spacer(minLength: 0)
            bottomToolbar
                .padding(.horizontal, Layout.pageMargin)
                .padding(.bottom, 12)
        }
        .background(Color.pageBackground.ignoresSafeArea())
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(hasChanges)
        .onAppear {
            loadIfEditing()
            // PRD §1.4: get to typing fast — focus the body so the keyboard is
            // up immediately on a new entry (skip for edit so回填内容 stays visible).
            if case .create = mode {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { editorFocused = true }
            }
        }
        .sheet(isPresented: $showDatePicker) { datePickerSheet }
        .confirmationDialog("添加图片", isPresented: $photoSourceDialog, titleVisibility: .visible) {
            Button("从相册选择") { showPhotoLibrary = true }
            Button("拍照") { showCamera = true }
            Button("取消", role: .cancel) {}
        }
        .photosPicker(isPresented: $showPhotoLibrary, selection: $photosPickerItem, matching: .images)
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { image in addImage(image) }
                .ignoresSafeArea()
        }
        .onChange(of: photosPickerItem) { _, newItem in
            guard let newItem else { return }
            Task { await loadPickedPhoto(newItem) }
        }
        .confirmationDialog("放弃本次修改？", isPresented: $showDiscardConfirm, titleVisibility: .visible) {
            Button("放弃修改", role: .destructive) { performCancel() }
            Button("继续编辑", role: .cancel) {}
        }
        .alert(
            permissionAlert?.title ?? "",
            isPresented: Binding(
                get: { permissionAlert != nil },
                set: { if !$0 { permissionAlert = nil } }
            ),
            presenting: permissionAlert
        ) { _ in
            Button("取消", role: .cancel) {}
            Button("去设置") { openSettings() }
        } message: { kind in
            Text(kind.message)
        }
        .alert("提示", isPresented: .init(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("好", role: .cancel) {}
        } message: { Text(errorMessage ?? "") }
    }

    // MARK: Nav row

    private var navRow: some View {
        ZStack {
            // Center date pill — tap to change the entry's date (back-dating).
            Button {
                editorFocused = false
                showDatePicker = true
            } label: {
                HStack(spacing: 5) {
                    Text(DiaryDateFormat.shortChinese(diaryDate))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 13)
                .padding(.vertical, 7)
                .background(Color.cardBackground, in: Capsule())
            }
            .buttonStyle(.plain)

            HStack {
                Button("取消") { cancelTapped() }
                    .font(.body17)
                    .foregroundStyle(Color.brand)
                    .accessibilityIdentifier("editor.cancel")
                Spacer()
                Button("保存") { save() }
                    .font(.navTitle17)
                    .foregroundStyle(canSave ? Color.brand : Color(uiColor: .tertiaryLabel))
                    .disabled(!canSave)
                    .accessibilityIdentifier("editor.save")
            }
        }
        .frame(height: 44)
        .padding(.horizontal, Layout.pageMargin)
        .padding(.top, 8)
    }

    // MARK: Content (text + photos + recording bar)

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topLeading) {
                    if text.isEmpty {
                        Text("今天想说点什么…")
                            .font(.body17)
                            .foregroundStyle(Color(uiColor: .tertiaryLabel))
                            .padding(.top, 8)
                            .padding(.leading, 5)
                    }
                    TextEditor(text: $text)
                        .font(.body17)
                        .lineSpacing(4)
                        .frame(minHeight: 120)
                        .scrollContentBackground(.hidden)
                        .focused($editorFocused)
                        .disabled(transcriber.isTranscribing) // live dictation drives the text
                        .accessibilityIdentifier("editor.text")
                }
                .padding(.top, 4)

                EditorMetadataView(
                    mood: $mood, weather: $weather, weatherText: $weatherText, tags: $tags,
                    locationName: $locationName, latitude: $latitude, longitude: $longitude
                )
                .padding(.top, 12)

                if !images.isEmpty || images.count < Layout.maxImages {
                    photoGrid.padding(.top, 12)
                }

                if let audio {
                    RecordingBar(audio: audio) { removeAudio() }
                        .padding(.top, 14)
                }
            }
            .padding(.horizontal, Layout.pageMargin)
        }
    }

    private var photoGrid: some View {
        let columns = Array(repeating: GridItem(.fixed(Layout.gridThumbnail), spacing: 8), count: 3)
        return LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(images) { item in
                ZStack(alignment: .topTrailing) {
                    item.thumbnail(side: Layout.gridThumbnail)
                    Button { removeImage(item) } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 20, height: 20)
                            .background(Color.black.opacity(0.5), in: Circle())
                    }
                    .padding(4)
                }
            }
            if images.count < Layout.maxImages {
                Button { photoSourceDialog = true } label: {
                    RoundedRectangle(cornerRadius: Layout.thumbnailRadius, style: .continuous)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                        .foregroundStyle(Color(uiColor: .tertiaryLabel))
                        .frame(width: Layout.gridThumbnail, height: Layout.gridThumbnail)
                        .overlay {
                            Image(systemName: "plus")
                                .font(.system(size: 20, weight: .regular))
                                .foregroundStyle(Color(uiColor: .tertiaryLabel))
                        }
                }
            }
        }
    }

    // MARK: Bottom toolbar / recording state

    @ViewBuilder
    private var bottomToolbar: some View {
        if recorder.isRecording {
            RecordingCapsule(
                elapsed: recorder.elapsed,
                levels: recorder.levels,
                onStop: { recorder.stop() }
            )
        } else {
            HStack(spacing: 0) {
                toolbarButton(
                    title: "转文字",
                    system: transcriber.isTranscribing ? "mic.fill" : "mic",
                    active: transcriber.isTranscribing,
                    action: toggleTranscription
                )
                toolbarButton(title: "录音", system: "waveform", action: startRecording)
                toolbarButton(title: "图片", system: "photo", action: { photoSourceDialog = true })
            }
            .padding(.vertical, 9)
            .padding(.horizontal, 6)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5))
        }
    }

    private func toolbarButton(title: String, system: String, active: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: system)
                    .font(.system(size: 22))
                    .foregroundStyle(active ? Color.brand : .primary)
                Text(title)
                    .font(.label11)
                    .foregroundStyle(active ? Color.brand : .secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private var datePickerSheet: some View {
        NavigationStack {
            DatePicker("日记日期", selection: $diaryDate, in: ...Date(), displayedComponents: .date)
                .datePickerStyle(.graphical)
                .environment(\.locale, Locale(identifier: "zh_CN"))
                .padding()
                .navigationTitle("选择日期")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("完成") { showDatePicker = false }
                    }
                }
        }
        .presentationDetents([.medium])
    }

    // MARK: Save / cancel

    private var canSave: Bool {
        !recorder.isRecording && (
            !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || !images.isEmpty
                || audio != nil
        )
    }

    private var hasChanges: Bool {
        text != initialText
            || images.count != initialImageCount
            || (audio != nil) != initialHadAudio
            || mood != initialMood
            || weather != initialWeather
            || tags != initialTags
            || locationName != initialLocation
    }

    private func cancelTapped() {
        transcriber.stop()
        if recorder.isRecording { recorder.cancel() }
        if hasChanges { showDiscardConfirm = true } else { performCancel() }
    }

    private func performCancel() {
        // Drop any freshly-recorded temp audio that was never saved.
        if case .new(let url, _)? = audio { try? FileManager.default.removeItem(at: url) }
        dismiss()
    }

    private func save() {
        transcriber.stop()
        let existing: DiaryEntry? = if case .edit(let e) = mode { e } else { nil }
        let draft = DiaryDraft(
            text: text, diaryDate: diaryDate,
            mood: mood, weather: weather, weatherText: weatherText, tags: tags,
            locationName: locationName, latitude: latitude, longitude: longitude,
            images: images, audio: audio
        )
        do {
            try DiaryService.save(draft, existing: existing, into: context)
            dismiss()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "存储空间可能不足，请重试。"
        }
    }

    private func loadIfEditing() {
        guard case .edit(let entry) = mode else {
            initialText = text
            return
        }
        text = entry.text
        diaryDate = entry.diaryDate
        mood = entry.mood
        weather = entry.weather
        weatherText = entry.weatherText
        tags = entry.tags
        locationName = entry.locationName
        latitude = entry.latitude
        longitude = entry.longitude
        images = entry.imageFileNames.map { .existing($0) }
        if let name = entry.audioFileName {
            audio = .existing(name, entry.audioDuration ?? 0)
        }
        initialText = entry.text
        initialImageCount = images.count
        initialHadAudio = audio != nil
        initialMood = mood
        initialWeather = weather
        initialTags = tags
        initialLocation = locationName
    }

    // MARK: Photos

    private func loadPickedPhoto(_ item: PhotosPickerItem) async {
        if let data = try? await item.loadTransferable(type: Data.self),
           let img = UIImage(data: data) {
            await MainActor.run { addImage(img); photosPickerItem = nil }
        }
    }

    private func addImage(_ image: UIImage) {
        guard images.count < Layout.maxImages else { return }
        images.append(.new(image, UUID()))
    }

    private func removeImage(_ item: EditorImage) {
        images.removeAll { $0.id == item.id }
    }

    // MARK: Recording

    private func startRecording() {
        editorFocused = false
        transcriber.stop()
        Task {
            let granted = await recorder.requestPermission()
            guard granted else { permissionAlert = .microphone; return }
            recorder.onFinish = { url, duration in
                // Replace any existing recording (max 1 per entry).
                if case .new(let old, _)? = audio { try? FileManager.default.removeItem(at: old) }
                audio = .new(url, duration)
            }
            do { try recorder.start() }
            catch { errorMessage = "无法开始录音，请检查麦克风。" }
        }
    }

    private func removeAudio() {
        if case .new(let url, _)? = audio { try? FileManager.default.removeItem(at: url) }
        audio = nil
    }

    // MARK: Transcription

    private func toggleTranscription() {
        if transcriber.isTranscribing { transcriber.stop(); return }
        editorFocused = false
        Task {
            let ok = await transcriber.requestAuthorization()
            guard ok else { permissionAlert = .speech; return }
            transcribeBase = text.isEmpty ? "" : text + " "
            do {
                try transcriber.start(
                    onUpdate: { recognized in text = transcribeBase + recognized },
                    onError: { message in errorMessage = message }
                )
            } catch {
                if transcriber.authorizationDenied { permissionAlert = .speech }
                else { errorMessage = (error as? LocalizedError)?.errorDescription ?? "语音识别不可用。" }
            }
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Permission alert kind
// (EditorImage / DraftAudio / DiaryDraft live in Models/DiaryDraft.swift so the
//  persistence logic in DiaryService can be unit-tested without the views.)

enum PermissionKind: Identifiable {
    case microphone, speech
    var id: Int { hashValue }
    var title: String {
        switch self {
        case .microphone: return "需要麦克风权限"
        case .speech: return "需要麦克风与语音识别权限"
        }
    }
    var message: String {
        switch self {
        case .microphone:
            return "请在设置中允许随心记使用麦克风，用于录制语音日记和语音转文字。"
        case .speech:
            return "请在设置中允许随心记使用麦克风和语音识别，把你说的话转换成日记文字。"
        }
    }
}

#Preview {
    EditorView(mode: .create)
        .modelContainer(for: DiaryEntry.self, inMemory: true)
        .tint(.brand)
}
