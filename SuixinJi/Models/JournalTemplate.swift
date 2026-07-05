import Foundation

/// 引导式模板日记 (evolution). Structured starter texts that scaffold a new entry —
/// picked up from the 今日灵感 / 写作习惯 nudges. The body is Markdown so it renders
/// with headings in the detail view. Pure & testable; the editor just drops `body`
/// into a fresh entry.
struct JournalTemplate: Identifiable, Equatable {
    let id: String
    let title: String
    let symbol: String   // SF Symbol
    let body: String

    /// All built-in templates, in display order.
    static let all: [JournalTemplate] = [
        JournalTemplate(
            id: "three-questions",
            title: "每日三问",
            symbol: "questionmark.circle",
            body: """
            ## 每日三问

            **🌟 今天最开心的一件事**


            **📖 今天学到 / 收获了什么**


            **💪 明天想做得更好的一点**

            """
        ),
        JournalTemplate(
            id: "gratitude",
            title: "感恩日记",
            symbol: "heart",
            body: """
            ## 感恩日记

            今天，我想感恩这三件事：

            1.
            2.
            3.
            """
        ),
        JournalTemplate(
            id: "morning",
            title: "晨间计划",
            symbol: "sunrise",
            body: """
            ## 晨间计划

            **今天最重要的三件事**
            1.
            2.
            3.

            **此刻的心情 / 期待**

            """
        ),
        JournalTemplate(
            id: "evening",
            title: "晚间复盘",
            symbol: "moon.stars",
            body: """
            ## 晚间复盘

            **今天完成了什么**


            **今天的高光时刻**


            **明天的第一步**

            """
        ),
    ]

    static func template(id: String) -> JournalTemplate? {
        all.first { $0.id == id }
    }
}
