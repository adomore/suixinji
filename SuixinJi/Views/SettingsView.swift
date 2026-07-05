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

    @State private var reminderDate = Date()
    @State private var notifyDenied = false

    // Backup / restore
    @State private var shareItem: ShareItem?
    @State private var showImporter = false
    @State private var resultMessage: String?

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
                Button { exportBackup() } label: {
                    Label("导出备份", systemImage: "square.and.arrow.up")
                }
                .accessibilityIdentifier("settings.export")
                Button { showImporter = true } label: {
                    Label("导入备份", systemImage: "square.and.arrow.down")
                }
                .accessibilityIdentifier("settings.import")
            } footer: {
                Text("导出为一个 .json 文件（含图片与录音），换机或重装后可导入恢复。导入按 id 合并，不会覆盖已有日记。")
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
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
            handleImport(result)
        }
        .alert("提示", isPresented: Binding(
            get: { resultMessage != nil }, set: { if !$0 { resultMessage = nil } }
        )) {
            Button("好", role: .cancel) {}
        } message: { Text(resultMessage ?? "") }
    }

    // MARK: Backup actions

    private func exportBackup() {
        do {
            shareItem = ShareItem(url: try BackupService.writeBackupFile(from: allEntries))
        } catch {
            resultMessage = "导出失败：\(error.localizedDescription)"
        }
    }

    private func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            do {
                let data = try Data(contentsOf: url)
                let r = try BackupService.importData(data, into: context)
                resultMessage = "导入完成：新增 \(r.imported) 篇，跳过 \(r.skipped) 篇。"
            } catch {
                resultMessage = "导入失败：文件可能不是有效的随心记备份。"
            }
        case .failure(let error):
            resultMessage = "导入失败：\(error.localizedDescription)"
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
