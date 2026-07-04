import SwiftUI

/// Settings (UI Brief §4 ④, extended for P1/P2). System grouped-list style.
/// 每日提醒 (F10 · real) · 应用锁 (F12) · iCloud 同步 (F11) · 关于 · data footer.
struct SettingsView: View {
    @EnvironmentObject private var lock: AppLockManager

    @AppStorage("dailyReminderEnabled") private var reminderEnabled = false
    @AppStorage("dailyReminderTime") private var reminderTime = "21:00"

    @State private var reminderDate = Date()
    @State private var notifyDenied = false

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    var body: some View {
        List {
            // MARK: 每日提醒 (F10)
            Section {
                Toggle("每日提醒", isOn: $reminderEnabled)
                    .tint(.brand)
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
                .tint(.brand)
                .disabled(!lock.isAvailable)
            } footer: {
                Text(lock.isAvailable
                     ? "开启后，每次打开随心记需通过 Face ID、Touch ID 或设备密码。"
                     : "此设备未设置密码或生物识别，无法开启应用锁。")
            }

            // MARK: iCloud 同步 (F11)
            Section {
                HStack {
                    Text("iCloud 同步")
                    Spacer()
                    Text(cloudStatus).foregroundStyle(.secondary)
                }
            } footer: {
                Text(cloudFooter)
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
        .alert("需要通知权限", isPresented: $notifyDenied) {
            Button("取消", role: .cancel) {}
            Button("去设置") {
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            }
        } message: {
            Text("请在设置中允许随心记发送通知，用于每日提醒。")
        }
    }

    // MARK: iCloud status text

    private var cloudStatus: String {
        #if CLOUDKIT_ENABLED
        return "已开启"
        #else
        return "未配置"
        #endif
    }

    private var cloudFooter: String {
        #if CLOUDKIT_ENABLED
        return "日记通过你的 iCloud 账号在设备间自动同步。"
        #else
        return "需在 Xcode 开启 iCloud/CloudKit 能力并使用付费开发者账号后启用（见 BUILD.md）。"
        #endif
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
        .environmentObject(AppLockManager())
        .tint(.brand)
}
