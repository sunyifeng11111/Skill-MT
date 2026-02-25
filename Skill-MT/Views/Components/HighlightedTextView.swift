import SwiftUI
import AppKit

struct HighlightedTextView: NSViewRepresentable {

    @Binding var text: String

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let textView = scrollView.documentView as? NSTextView else { return scrollView }

        textView.isEditable = true
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.backgroundColor = .clear
        textView.drawsBackground = false

        // Attach highlighter as text storage delegate
        textView.textStorage?.delegate = context.coordinator.highlighter

        textView.delegate = context.coordinator

        // Set initial text and highlight
        textView.string = text
        if let storage = textView.textStorage {
            context.coordinator.highlighter.highlight(storage)
        }

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        // Avoid loop: only update if SwiftUI binding changed externally
        guard textView.string != text else { return }
        context.coordinator.isUpdatingFromSwiftUI = true
        let selectedRanges = textView.selectedRanges
        textView.string = text
        if let storage = textView.textStorage {
            context.coordinator.highlighter.highlight(storage)
        }
        textView.selectedRanges = selectedRanges
        context.coordinator.isUpdatingFromSwiftUI = false
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: HighlightedTextView
        let highlighter = MarkdownHighlighter()
        var isUpdatingFromSwiftUI = false

        init(_ parent: HighlightedTextView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard !isUpdatingFromSwiftUI,
                  let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
    }
}
