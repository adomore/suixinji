import Foundation
import NaturalLanguage

/// 关键词洞察 (evolution). Surfaces the words a diary returns to most. Uses
/// `NLTokenizer` for word segmentation (handles Chinese, which has no spaces), then
/// counts after dropping function words and one-character tokens. The counting/
/// filtering is pure & unit-testable; only `tokenize` touches the OS tokenizer.
enum KeywordInsights {
    struct WordCount: Identifiable, Equatable {
        let word: String
        let count: Int
        var id: String { word }
    }

    /// Common function words to ignore. One-character tokens are dropped separately,
    /// which already removes most Chinese particles (的/了/是/在…); these are the
    /// frequent two-character ones plus a few English stopwords.
    static let stopwords: Set<String> = [
        // Chinese (two-char function/filler words)
        "今天", "昨天", "明天", "一个", "什么", "自己", "我们", "你们", "他们", "她们",
        "这个", "那个", "这些", "那些", "因为", "所以", "但是", "可以", "没有", "就是",
        "还是", "这样", "那样", "现在", "时候", "一下", "一点", "有点", "觉得", "知道",
        "应该", "已经", "然后", "于是", "而且", "不过", "如果", "或者", "一直", "有些",
        "非常", "特别", "真的", "好像", "感觉", "开始", "或许", "似乎",
        // English
        "the", "and", "for", "you", "that", "this", "with", "have", "was", "are",
        "but", "not", "all", "can", "would", "could", "there", "their", "they",
        "from", "your", "just", "about", "what", "when", "then", "them", "were"
    ]

    /// A token worth counting: at least two characters, not a stopword, and containing
    /// an actual letter (so pure punctuation / numbers / emoji are dropped).
    static func isMeaningful(_ token: String) -> Bool {
        guard token.count >= 2, !stopwords.contains(token) else { return false }
        return token.unicodeScalars.contains { CharacterSet.letters.contains($0) }
    }

    /// Rank tokens by frequency (desc), ties broken alphabetically. Pure & testable.
    static func rank(_ tokens: [String], limit: Int = 12) -> [WordCount] {
        var counts: [String: Int] = [:]
        for raw in tokens {
            let w = raw.lowercased()
            guard isMeaningful(w) else { continue }
            counts[w, default: 0] += 1
        }
        let sorted = counts
            .map { WordCount(word: $0.key, count: $0.value) }
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0.word < $1.word }
        return Array(sorted.prefix(limit))
    }

    /// Split text into word tokens using the OS tokenizer.
    static func tokenize(_ text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        var out: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            out.append(String(text[range]))
            return true
        }
        return out
    }

    /// The most frequent meaningful words across the given entries' text.
    static func topWords(from entries: [DiaryEntry], limit: Int = 12) -> [WordCount] {
        rank(tokenize(entries.map(\.text).joined(separator: "\n")), limit: limit)
    }
}
