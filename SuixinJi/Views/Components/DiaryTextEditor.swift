import SwiftUI
import UIKit

/// A `UITextView`-backed multiline editor that exposes the caret/selection, so
/// speech-to-text can insert **at the cursor** in real time (PRD §3.2 F2).
/// SwiftUI's `TextEditor` gives no access to the caret, hence this bridge.
///
/// Two-way binds `text` and `selectedRange` (UTF-16), reconciles first-responder
/// state with `isFocused`, and draws a placeholder when empty. A `updating` flag
/// prevents delegate callbacks fired during programmatic updates from writing
/// back into SwiftUI state mid-view-update.
struct DiaryTextEditor: UIViewRepresentable {
    @Binding var text: String
    @Binding var selectedRange: NSRange
    @Binding var isFocused: Bool
    var placeholder: String
    var accessibilityID: String?

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.delegate = context.coordinator
        tv.font = .systemFont(ofSize: 17)
        tv.backgroundColor = .clear
        tv.textContainerInset = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        tv.textContainer.lineFragmentPadding = 0
        tv.isScrollEnabled = false           // grow to fit; the outer ScrollView scrolls
        tv.accessibilityIdentifier = accessibilityID

        // Placeholder label overlaid at the text origin.
        let ph = UILabel()
        ph.text = placeholder
        ph.font = .systemFont(ofSize: 17)
        ph.textColor = .tertiaryLabel
        ph.numberOfLines = 0
        ph.translatesAutoresizingMaskIntoConstraints = false
        tv.addSubview(ph)
        NSLayoutConstraint.activate([
            ph.topAnchor.constraint(equalTo: tv.topAnchor, constant: 8),
            ph.leadingAnchor.constraint(equalTo: tv.leadingAnchor, constant: 0),
            ph.trailingAnchor.constraint(lessThanOrEqualTo: tv.trailingAnchor, constant: -4),
        ])
        context.coordinator.placeholder = ph

        tv.text = text
        ph.isHidden = !text.isEmpty
        return tv
    }

    func updateUIView(_ tv: UITextView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        coordinator.updating = true
        defer { coordinator.updating = false }

        if tv.text != text { tv.text = text }
        coordinator.placeholder?.isHidden = !text.isEmpty

        // Apply a programmatic caret/selection if it's valid and different.
        let length = (tv.text as NSString).length
        if selectedRange.location <= length,
           selectedRange.location + selectedRange.length <= length,
           tv.selectedRange != selectedRange {
            tv.selectedRange = selectedRange
        }

        // Reconcile keyboard focus with the binding.
        if isFocused, !tv.isFirstResponder {
            tv.becomeFirstResponder()
        } else if !isFocused, tv.isFirstResponder {
            tv.resignFirstResponder()
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: DiaryTextEditor
        weak var placeholder: UILabel?
        var updating = false

        init(_ parent: DiaryTextEditor) { self.parent = parent }

        func textViewDidChange(_ tv: UITextView) {
            guard !updating else { return }
            parent.text = tv.text
            parent.selectedRange = tv.selectedRange
            placeholder?.isHidden = !tv.text.isEmpty
        }

        func textViewDidChangeSelection(_ tv: UITextView) {
            guard !updating else { return }
            parent.selectedRange = tv.selectedRange
        }

        func textViewDidBeginEditing(_ tv: UITextView) {
            guard !updating else { return }
            parent.isFocused = true
        }

        func textViewDidEndEditing(_ tv: UITextView) {
            guard !updating else { return }
            parent.isFocused = false
        }
    }
}
