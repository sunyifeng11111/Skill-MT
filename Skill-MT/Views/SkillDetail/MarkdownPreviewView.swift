import SwiftUI
import AppKit

struct MarkdownPreviewView: View {
    @Environment(\.localization) private var localization
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader(localization.string("Content"))

            if content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(localization.string("No content"))
                    .foregroundStyle(.tertiary)
                    .italic()
                    .padding()
            } else {
                RenderedMarkdownTextView(text: content)
                .padding(12)
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

private final class AutoHeightRenderedTextView: NSTextView {
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

    override func layout() {
        super.layout()
        invalidateIntrinsicContentSize()
    }
}

private struct RenderedMarkdownTextView: NSViewRepresentable {
    let text: String

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> AutoHeightRenderedTextView {
        let tv = AutoHeightRenderedTextView()
        tv.isEditable = false
        tv.isSelectable = true
        tv.drawsBackground = false
        tv.isRichText = true
        tv.textContainerInset = NSSize(width: 8, height: 8)
        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = false
        tv.autoresizingMask = .width
        tv.textContainer?.widthTracksTextView = true
        tv.textContainer?.lineFragmentPadding = 0
        tv.setContentHuggingPriority(.defaultLow, for: .horizontal)
        tv.setContentHuggingPriority(.required, for: .vertical)
        tv.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        tv.setContentCompressionResistancePriority(.required, for: .vertical)
        applyMarkdown(text, to: tv)
        context.coordinator.lastSourceText = text
        return tv
    }

    func updateNSView(_ tv: AutoHeightRenderedTextView, context: Context) {
        guard context.coordinator.lastSourceText != text else { return }
        applyMarkdown(text, to: tv)
        context.coordinator.lastSourceText = text
        tv.invalidateIntrinsicContentSize()
    }

    private func applyMarkdown(_ text: String, to textView: NSTextView) {
        if let rendered = renderedAttributedString(from: text) {
            textView.textStorage?.setAttributedString(rendered)
        } else {
            textView.string = text
            textView.font = .systemFont(ofSize: 14)
            textView.textColor = .labelColor
        }
    }

    private func renderedAttributedString(from markdown: String) -> NSAttributedString? {
        let source: AttributedString
        do {
            source = try AttributedString(
                markdown: markdown,
                options: .init(
                    interpretedSyntax: .full,
                    failurePolicy: .returnPartiallyParsedIfPossible
                )
            )
        } catch {
            return nil
        }

        let output = NSMutableAttributedString()
        var lastBlockID: Int?
        var lastListID: Int?
        var lastWasListItem = false

        for run in source.runs {
            let segment = String(source[run.range].characters)
            guard !segment.isEmpty else { continue }

            let context = runContext(from: run.presentationIntent)

            if let blockID = context.blockID, blockID != lastBlockID {
                if output.length > 0 {
                    if context.isListItem && lastWasListItem && lastListID == context.listID {
                        output.append(NSAttributedString(string: "\n"))
                    } else {
                        output.append(NSAttributedString(string: "\n\n"))
                    }
                }

                if context.isListItem {
                    let marker = context.isOrderedList
                        ? "\(context.listOrdinal ?? 1). "
                        : "• "
                    output.append(
                        NSAttributedString(
                            string: marker,
                            attributes: [.foregroundColor: NSColor.secondaryLabelColor]
                        )
                    )
                } else if context.isBlockQuote {
                    output.append(
                        NSAttributedString(
                            string: "▍ ",
                            attributes: [.foregroundColor: NSColor.tertiaryLabelColor]
                        )
                    )
                }
            }

            output.append(
                NSAttributedString(
                    string: segment,
                    attributes: attributes(for: run, context: context)
                )
            )

            if let blockID = context.blockID {
                lastBlockID = blockID
                lastListID = context.listID
                lastWasListItem = context.isListItem
            }
        }

        return output
    }

    private func runContext(from intent: PresentationIntent?) -> MarkdownRunContext {
        guard let intent else { return MarkdownRunContext() }

        var context = MarkdownRunContext()
        for component in intent.components {
            if context.blockID == nil {
                context.blockID = component.identity
            }
            switch component.kind {
            case .header(let level):
                context.headerLevel = level
            case .codeBlock:
                context.isCodeBlock = true
            case .blockQuote:
                context.isBlockQuote = true
            case .listItem(let ordinal):
                context.isListItem = true
                context.listOrdinal = ordinal
            case .orderedList:
                context.isOrderedList = true
                context.listID = component.identity
            case .unorderedList:
                context.listID = component.identity
            case .paragraph, .thematicBreak, .table, .tableHeaderRow, .tableRow, .tableCell:
                break
            @unknown default:
                break
            }
        }

        return context
    }

    private func attributes(
        for run: AttributedString.Runs.Element,
        context: MarkdownRunContext
    ) -> [NSAttributedString.Key: Any] {
        var fontWeight: NSFont.Weight = .regular
        var italic = false
        var fontSize: CGFloat = 14
        var textColor = NSColor.labelColor

        if let level = context.headerLevel {
            switch level {
            case 1: fontSize = 24
            case 2: fontSize = 20
            case 3: fontSize = 18
            default: fontSize = 16
            }
            fontWeight = .semibold
        }

        if let inline = run.inlinePresentationIntent {
            if inline.contains(.stronglyEmphasized) {
                fontWeight = .bold
            }
            if inline.contains(.emphasized) {
                italic = true
            }
            if inline.contains(.code) {
                fontSize = 13
            }
        }

        if context.isCodeBlock {
            fontSize = 13
        }

        if context.isBlockQuote {
            textColor = .secondaryLabelColor
        }

        let font: NSFont
        if context.isCodeBlock || run.inlinePresentationIntent?.contains(.code) == true {
            font = .monospacedSystemFont(ofSize: fontSize, weight: fontWeight)
        } else if italic {
            let descriptor = NSFont.systemFont(ofSize: fontSize, weight: fontWeight)
                .fontDescriptor
                .withSymbolicTraits(.italic)
            font = NSFont(descriptor: descriptor, size: fontSize)
                ?? NSFont.systemFont(ofSize: fontSize, weight: fontWeight)
        } else {
            font = NSFont.systemFont(ofSize: fontSize, weight: fontWeight)
        }

        var attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor
        ]

        if let link = run.link {
            attributes[.link] = link
            attributes[.foregroundColor] = NSColor.systemBlue
            attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
        }

        if context.isCodeBlock || run.inlinePresentationIntent?.contains(.code) == true {
            attributes[.backgroundColor] = NSColor.controlBackgroundColor.withAlphaComponent(0.6)
        }

        return attributes
    }

    final class Coordinator {
        var lastSourceText: String = ""
    }
}

private struct MarkdownRunContext {
    var blockID: Int?
    var headerLevel: Int?
    var isCodeBlock: Bool = false
    var isBlockQuote: Bool = false
    var isListItem: Bool = false
    var listOrdinal: Int?
    var isOrderedList: Bool = false
    var listID: Int?
}
