import Foundation

/// Pure logic for inserting live speech-to-text at the caret (PRD §3.2 F2).
/// A dictation session is anchored at `anchor`; each partial result replaces the
/// previous chunk (`previousChunkLength`) in place, so the text grows at the
/// cursor rather than at the end. All offsets are UTF-16 (to match UITextView).
enum Dictation {
    struct Result: Equatable {
        let text: String
        let caret: Int          // UTF-16 offset of the caret after insertion
        let chunkLength: Int    // UTF-16 length of the inserted chunk
    }

    static func insert(
        into text: String,
        anchor: Int,
        previousChunkLength: Int,
        recognized: String
    ) -> Result {
        let ns = text as NSString
        let start = max(0, min(anchor, ns.length))
        let length = max(0, min(previousChunkLength, ns.length - start))
        let newText = ns.replacingCharacters(in: NSRange(location: start, length: length), with: recognized)
        let chunk = (recognized as NSString).length
        return Result(text: newText, caret: start + chunk, chunkLength: chunk)
    }
}
