import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Settings (UI Brief §4 ④, extended for P1/P2 + backup). System grouped-list.
/// 每日提醒 (F10) · 应用锁 (F12) · 数据备份 (evolution) · iCloud (F11) · 关于 · footer.
struct SettingsView: View {
    @EnvironmentObject private var lock: AppLockManager
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.modelContext) private var context
    @Query private var allEntries: [DiaryEntry]

    @AppStorage("dailyReminderEnabled") private var reminderEnabled = false
    @AppStorage("dailyReminderTime") private var reminderTime = "21:00"
    @AppStorage("healthSyncEnabled") private var healthSyncEnabled = false
    @AppStorage("showLunarDate") private var showLunar = true

    @State private var reminderDate = Date()
    @State private var notifyDenied = false

    // Backup / restore
    @State private var shareItem: ShareItem?
    @State private var showImporter = false
    @State private var resultMessage: String?
    // 数据加密 (evolution): optional password on export, prompt on encrypted import.
    @State private var showExportChoice = false
    @State private var showExportPassword = false
    @State private var exportPassword = ""
    @State private var pendingImportData: Data?
    @State private var showImportPassword = false
    @State private var importPassword = ""
    @State private var generatingBook = false

    // iCloud (F11)
    @State private var iCloudStatus = "检查中…"

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    var body: some View {
        List {
            // MARK: 外观 (evolution — theme skin)
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text("强调色").scaledFont(13).foregroundStyle(.secondary)
                    HStack(spacing: 16) {
                        ForEach(ThemeManager.AccentOption.allCases) { opt in
                            Button { theme.accent = opt } label: {
                                Circle().fill(opt.color).frame(width: 28, height: 28)
                                    .overlay(
                                        Circle().strokeBorder(Color.primary, lineWidth: 2)
                                            .padding(-3)
                                            .opacity(theme.accent == opt ? 0.9 : 0)
                                    )
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("accent.\(opt.rawValue)")
                        }
                        Spacer()
                    }
                }
                .padding(.vertical, 4)

                Picker("字号", selection: $theme.fontScale) {
                    ForEach(ThemeManager.FontScaleOption.allCases) { Text(LocalizedStringKey($0.name)).tag($0) }
                }
                .pickerStyle(.segmented)

                Toggle("显示农历日期", isOn: $showLunar)
            } header: {
                Text("外观")
            }

            // MARK: 每日提醒 (F10)
            Section {
                Toggle("每日提醒", isOn: $reminderEnabled)
                    .onChange(of: reminderEnabled) { _, on in toggleReminder(on) }
                if reminderEnabled {
                    DatePicker("提醒时间", selection: $reminderDate, displayedComponents: .hourAndMinute)
                        .environment(\.locale, Locale(identifier: "zh_CN"))
                        .onChange(of: reminderDate) { _, _ in rescheduleFromDate() }
                }
            } footer: {
                Text("到点推送一条本地提醒，提醒你写日记。")
            }

            // MARK: 应用锁 (F12)
            Section {
                Toggle("应用锁（Face ID / 密码）", isOn: Binding(
                    get: { lock.enabled },
                    set: { lock.enabled = $0 }
                ))
                .disabled(!lock.isAvailable)
            } footer: {
                Text(lock.isAvailable
                     ? "开启后，每次打开随心记需通过 Face ID、Touch ID 或设备密码。"
                     : "此设备未设置密码或生物识别，无法开启应用锁。")
            }

            // MARK: 健康联动 (evolution — Apple Health · State of Mind)
            if HealthService.shared.isSupported {
                Section {
                    Toggle("同步心情到「健康」", isOn: $healthSyncEnabled)
                        .onChange(of: healthSyncEnabled) { _, on in if on { enableHealthSync() } }
                        .accessibilityIdentifier("settings.health")
                } footer: {
                    Text("开启后，保存带心情的日记时，会在「健康」App 记录一条对应的情绪（State of Mind）。仅写入，随心记不会读取你的健康数据。")
                }
            }

            // MARK: 内容管理 (evolution)
            Section {
                NavigationLink {
                    TagManagementView()
                } label: {
                    Label("标签管理", systemImage: "tag")
                }
                .accessibilityIdentifier("settings.tags")
            } footer: {
                Text("重命名、合并或删除标签，改动会应用到所有日记。")
            }

            // MARK: 数据备份 (evolution)
            Section {
                Button { showExportChoice = true } label: {
                    Label("导出备份", systemImage: "square.and.arrow.up")
                }
                .accessibilityIdentifier("settings.export")
                Button { showImporter = true } label: {
                    Label("导入备份", systemImage: "square.and.arrow.down")
                }
                .accessibilityIdentifier("settings.import")
                Button { exportBook() } label: {
                    HStack {
                        Label("导出整本日记（PDF）", systemImage: "book.closed")
                        if generatingBook { Spacer(); ProgressView() }
                    }
                }
                .disabled(generatingBook || allEntries.isEmpty)
                .accessibilityIdentifier("settings.exportBook")
            } footer: {
                Text("导出为一个含图片与录音的文件，换机或重装后可导入恢复。可选设置密码加密（AES-256），导入时需输入同一密码。导入按 id 合并，不会覆盖已有日记。")
            }

            // MARK: iCloud 同步 (F11)
            Section {
                HStack {
                    Text("iCloud 同步")
                    Spacer()
                    Text(LocalizedStringKey(iCloudStatus)).foregroundStyle(.secondary)
                }
            } footer: {
                Text("登录 iCloud 后，日记文字、图片与录音都会在你的设备间自动同步。")
            }

            // MARK: 关于 + data footer
            Section {
                HStack {
                    Text("关于")
                    Spacer()
                    Text("版本 \(appVersion)").foregroundStyle(.secondary)
                }
            } footer: {
                // MUST appear, verbatim (Brief §4 ④ / PRD §5.4).
                Text("日记仅保存在本机，删除 App 将丢失全部数据。")
            }
        }
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            let (h, m) = ReminderManager.parse(reminderTime)
            reminderDate = Calendar.current.date(bySettingHour: h, minute: m, second: 0, of: Date()) ?? Date()
        }
        .task {
            iCloudStatus = CloudStatus.describe(await CloudStatus.current())
        }
        .alert("需要通知权限", isPresented: $notifyDenied) {
            Button("取消", role: .cancel) {}
            Button("去设置") {
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            }
        } message: {
            Text("请在设置中允许随心记发送通知，用于每日提醒。")
        }
        .sheet(item: $shareItem) { ShareSheet(items: [$0.url]) }
        .fileImporter(isPresented: $showImporter,
                      allowedContentTypes: [.json, UTType(filenameExtension: "suixinji") ?? .data]) { result in
            handleImport(result)
        }
        .confirmationDialog("导出备份", isPresented: $showExportChoice, titleVisibility: .visible) {
            Button("直接导出") { exportBackup(password: nil) }
            Button("加密导出（设密码）") { exportPassword = ""; showExportPassword = true }
            Button("取消", role: .cancel) {}
        }
        .alert("设置备份密码", isPresented: $showExportPassword) {
            SecureField("密码（至少 4 位）", text: $exportPassword)
            Button("取消", role: .cancel) {}
            Button("导出") { exportBackup(password: exportPassword) }
                .disabled(exportPassword.count < 4)
        } message: {
            Text("导入时需要输入同一密码，忘记将无法恢复。")
        }
        .alert("输入备份密码", isPresented: $showImportPassword) {
            SecureField("密码", text: $importPassword)
            Button("取消", role: .cancel) { pendingImportData = nil }
            Button("解密导入") { importEncrypted() }
        } message: {
            Text("这是一个加密备份，请输入导出时设置的密码。")
        }
        .alert("提示", isPresented: Binding(
            get: { resultMessage != nil }, set: { if !$0 { resultMessage = nil } }
        )) {
            Button("好", role: .cancel) {}
        } message: { Text(resultMessage ?? "") }
    }

    // MARK: Backup actions

    private func exportBackup(password: String?) {
        do {
            shareItem = ShareItem(url: try BackupService.writeBackupFile(from: allEntries, password: password))
        } catch {
            resultMessage = "导出失败：\(error.localizedDescription)"
        }
    }

    /// 整本导出 (evolution): render the whole diary to a paginated PDF, then share it.
    private func exportBook() {
        generatingBook = true
        Task {
            // Let the spinner appear before the synchronous ImageRenderer work.
            try? await Task.sleep(nanoseconds: 50_000_000)
            let url = DiaryExporter.exportBook(from: allEntries)
            generatingBook = false
            if let url { shareItem = ShareItem(url: url) }
            else { resultMessage = "导出失败，请重试。" }
        }
    }

    private func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url) else {
                resultMessage = "导入失败：无法读取文件。"; return
            }
            if BackupCrypto.isEncrypted(data) {
                // Stash it and ask for the password.
                pendingImportData = data
                importPassword = ""
                showImportPassword = true
            } else {
                runImport(data, password: nil)
            }
        case .failure(let error):
            resultMessage = "导入失败：\(error.localizedDescription)"
        }
    }

    private func importEncrypted() {
        guard let data = pendingImportData else { return }
        runImport(data, password: importPassword)
        pendingImportData = nil
    }

    private func runImport(_ data: Data, password: String?) {
        do {
            let r = try BackupService.importData(data, into: context, password: password)
            resultMessage = "导入完成：新增 \(r.imported) 篇，跳过 \(r.skipped) 篇。"
        } catch BackupCrypto.CryptoError.wrongPassword {
            resultMessage = "密码不正确，无法解密该备份。"
        } catch {
            resultMessage = "导入失败：文件可能不是有效的随心记备份。"
        }
    }

    // MARK: Health actions

    private func enableHealthSync() {
        Task {
            let ok = await HealthService.shared.requestAuthorization()
            if !ok { healthSyncEnabled = false }
        }
    }

    // MARK: Reminder actions

    private func toggleReminder(_ on: Bool) {
        guard on else { ReminderManager.cancel(); return }
        Task {
            let granted = await ReminderManager.requestAuthorization()
            if granted {
                rescheduleFromDate()
            } else {
                reminderEnabled = false
                notifyDenied = true
            }
        }
    }

    private func rescheduleFromDate() {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: reminderDate)
        let h = comps.hour ?? 21, m = comps.minute ?? 0
        reminderTime = String(format: "%02d:%02d", h, m)
        guard reminderEnabled else { return }
        ReminderManager.schedule(hour: h, minute: m)
    }
}

#Preview {
    NavigationStack { SettingsView() }
        .modelContainer(for: DiaryEntry.self, inMemory: true)
        .environmentObject(AppLockManager())
        .environmentObject(ThemeManager())
        .tint(.brand)
}
