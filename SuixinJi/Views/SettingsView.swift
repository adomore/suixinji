import SwiftUI

/// Settings (UI Brief §4 ④). System grouped-list style, three parts only:
/// 每日提醒 (P1 placeholder) · 关于 (version) · the mandatory data-storage footer.
struct SettingsView: View {
    // P1 placeholder state — the toggle renders but does nothing yet.
    @AppStorage("dailyReminderEnabled") private var reminderEnabled = false
    @AppStorage("dailyReminderTime") private var reminderTime = "21:00"

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    var body: some View {
        List {
            // 每日提醒 (P1) — shown as a disabled placeholder for now.
            Section {
                Toggle("每日提醒", isOn: $reminderEnabled)
                    .tint(.brand)
                    .disabled(true)
                HStack {
                    Text("提醒时间")
                    Spacer()
                    Text(reminderTime)
                }
                .foregroundStyle(.tertiary)
            }

            Section {
                HStack {
                    Text("关于")
                    Spacer()
                    Text("版本 \(appVersion)")
                        .foregroundStyle(.secondary)
                }
            } footer: {
                // MUST appear, verbatim (Brief §4 ④ / PRD §5.4).
                Text("日记仅保存在本机，删除 App 将丢失全部数据。")
            }
        }
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { SettingsView() }.tint(.brand)
}
