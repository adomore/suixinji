import Foundation

/// 富文本 Markdown (evolution). Entries stay **plain text**; this parses them into
/// lightweight blocks for rendering (`MarkdownText`) at display time — no storage
/// change. Line-based on purpose: a diary's own line breaks are meaningful, so each
/// line maps to one block (blank line → spacing). Inline emphasis (**bold**,
/// *italic*, `code`, ~~strike~~, links) is left to `AttributedString(markdown:)`.
enum MarkdownBlock: Equatable {
    case heading(Int, String)      // level 1–3
    case bullet(String)
    case ordered(String, String)   // (number, text)
    case quote(String)
    case divider
    case paragraph(String)         // empty string = blank line (spacer)
}

enum MarkdownParser {
    static func blocks(from text: String) -> [MarkdownBlock] {
        text.components(separatedBy: "\n").map(classify)
    }

    static func classify(_ rawLine: String) -> MarkdownBlock {
        let s = rawLine.trimmingCharacters(in: .whitespaces)
        if s.isEmpty { return .paragraph("") }
        if isDivider(s) { return .divider }
        if let h = heading(s) { return h }
        if s == ">" { return .quote("") }
        if s.hasPrefix("> ") { return .quote(String(s.dropFirst(2))) }
        if s.hasPrefix("- ") || s.hasPrefix("* ") || s.hasPrefix("• ") {
            return .bullet(String(s.dropFirst(2)))
        }
        if let o = ordered(s) { return o }
        return .paragraph(s)
    }

    /// A clean one-line preview (markers + inline emphasis stripped) for cards.
    static func plainPreview(_ text: String) -> String {
        blocks(from: text).compactMap { block -> String? in
            switch block {
            case .divider: return nil
            case .paragraph(let t), .heading(_, let t), .bullet(let t), .quote(let t):
                return inlinePlain(t)
            case .ordered(_, let t):
                return inlinePlain(t)
            }
        }
        .filter { !$0.isEmpty }
        .joined(separator: " ")
    }

    /// Strip inline emphasis by letting AttributedString parse then taking its text.
    static func inlinePlain(_ s: String) -> String {
        guard let attr = try? AttributedString(
            markdown: s,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) else { return s }
        return String(attr.characters)
    }

    // MARK: Line classifiers

    private static func isDivider(_ s: String) -> Bool {
        guard s.count >= 3 else { return false }
        return ["-", "*", "_"].contains { ch in s.allSatisfy { String($0) == ch } }
    }

    private static func heading(_ s: String) -> MarkdownBlock? {
        if s.hasPrefix("### ") { return .heading(3, String(s.dropFirst(4))) }
        if s.hasPrefix("## ") { return .heading(2, String(s.dropFirst(3))) }
        if s.hasPrefix("# ") { return .heading(1, String(s.dropFirst(2))) }
        return nil
    }

    private static func ordered(_ s: String) -> MarkdownBlock? {
        let digits = s.prefix { $0.isNumber }
        guard !digits.isEmpty else { return nil }
        let rest = s.dropFirst(digits.count)
        guard rest.hasPrefix(". ") else { return nil }
        return .ordered(String(digits), String(rest.dropFirst(2)))
    }
}
