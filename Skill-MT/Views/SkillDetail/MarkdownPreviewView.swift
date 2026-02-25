import SwiftUI
import AppKit

struct MarkdownPreviewView: View {
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Content")

            if content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("No content")
                    .foregroundStyle(.tertiary)
                    .italic()
                    .padding()
            } else {
                HighlightedReadOnlyView(text: content)
                    .padding(8)
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 6)
    }
}

// MARK: - Self-sizing NSTextView subclass

private final class AutoHeightTextView: NSTextView {
    override var intrinsicContentSize: NSSize {
        guard let container = textContainer, let layout = layoutManager else {
            return super.intrinsicContentSize
        }
        layout.ensureLayout(for: container)
        let used = layout.usedRect(for: container)
        return NSSize(
            width: NSView.noIntrinsicMetric,
            height: used.height + textContainerInset.height * 2
        )
    }

    override func didChangeText() {
        super.didChangeText()
        invalidateIntrinsicContentSize()
    }

    override func layout() {
        super.layout()
        invalidateIntrinsicContentSize()
    }
}

// MARK: - NSViewRepresentable

private struct HighlightedReadOnlyView: NSViewRepresentable {
    let text: String

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> AutoHeightTextView {
        let tv = AutoHeightTextView()
        tv.isEditable = false
        tv.isSelectable = true
        tv.drawsBackground = false
        tv.isRichText = false
        tv.textContainerInset = NSSize(width: 8, height: 8)
        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = false
        tv.autoresizingMask = .width
        tv.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        tv.textContainer?.widthTracksTextView = true
        tv.textContainer?.lineFragmentPadding = 0
        tv.setContentHuggingPriority(.defaultLow, for: .horizontal)
        tv.setContentHuggingPriority(.required, for: .vertical)
        tv.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        tv.setContentCompressionResistancePriority(.required, for: .vertical)
        tv.textStorage?.delegate = context.coordinator.highlighter

        tv.string = text
        context.coordinator.highlighter.highlight(tv.textStorage!)
        return tv
    }

    func updateNSView(_ tv: AutoHeightTextView, context: Context) {
        guard tv.string != text else { return }
        tv.string = text
        context.coordinator.highlighter.highlight(tv.textStorage!)
        tv.invalidateIntrinsicContentSize()
    }

    final class Coordinator {
        let highlighter = MarkdownHighlighter()
    }
}

