import SwiftUI

/// Renders an entry's plain text with lightweight Markdown (evolution). Block
/// structure (headings / lists / quote / divider) comes from `MarkdownParser`;
/// inline emphasis (**bold** *italic* `code` ~~strike~~ links) from
/// `AttributedString(markdown:)`. Read-only — the editor stays plain text.
struct MarkdownText: View {
    let text: String
    var baseSize: CGFloat = 17

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            let blocks = MarkdownParser.blocks(from: text)
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                view(for: block)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private func view(for block: MarkdownBlock) -> some View {
        switch block {
        case .heading(let level, let t):
            inline(t)
                .scaledFont(headingSize(level), weight: .bold)
                .padding(.top, 2)
        case .bullet(let t):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("•").foregroundStyle(.secondary)
                inline(t).scaledFont(baseSize)
            }
        case .ordered(let n, let t):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(n).").scaledFont(baseSize).monospacedDigit().foregroundStyle(.secondary)
                inline(t).scaledFont(baseSize)
            }
        case .quote(let t):
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.accentColor.opacity(0.5)).frame(width: 3)
                inline(t).scaledFont(baseSize).foregroundStyle(.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
        case .divider:
            Divider().padding(.vertical, 2)
        case .paragraph(let t):
            if t.isEmpty {
                Color.clear.frame(height: 4)
            } else {
                inline(t).scaledFont(baseSize).lineSpacing(4)
            }
        }
    }

    private func headingSize(_ level: Int) -> CGFloat {
        switch level { case 1: return baseSize + 6; case 2: return baseSize + 3; default: return baseSize + 1 }
    }

    /// Inline-only Markdown → `Text`, falling back to plain on parse failure.
    private func inline(_ s: String) -> Text {
        if let attr = try? AttributedString(
            markdown: s,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            return Text(attr)
        }
        return Text(s)
    }
}
