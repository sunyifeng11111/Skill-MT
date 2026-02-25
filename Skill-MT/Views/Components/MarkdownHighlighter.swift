import AppKit

// MARK: - Theme

struct MarkdownTheme {
    let body:        NSFont
    let mono:        NSFont
    let h1:          NSFont
    let h2:          NSFont
    let h3:          NSFont
    let hN:          NSFont

    let textColor:       NSColor
    let headerColor:     NSColor
    let codeColor:       NSColor
    let codeBg:          NSColor
    let linkColor:       NSColor
    let quoteColor:      NSColor
    let punctColor:      NSColor
    let boldColor:       NSColor
    let listMarkerColor: NSColor

    static let `default` = MarkdownTheme()

    init() {
        let bodySize: CGFloat = 13
        body  = .systemFont(ofSize: bodySize)
        mono  = .monospacedSystemFont(ofSize: bodySize - 1, weight: .regular)
        h1    = .systemFont(ofSize: bodySize + 6, weight: .bold)
        h2    = .systemFont(ofSize: bodySize + 4, weight: .semibold)
        h3    = .systemFont(ofSize: bodySize + 2, weight: .semibold)
        hN    = .systemFont(ofSize: bodySize + 1, weight: .medium)

        textColor       = .labelColor
        headerColor     = NSColor(name: nil) { _ in .controlAccentColor }
        codeColor       = .secondaryLabelColor
        codeBg          = NSColor(name: nil) { app in
            app.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor.white.withAlphaComponent(0.07)
                : NSColor.black.withAlphaComponent(0.06)
        }
        linkColor       = .linkColor
        quoteColor      = .secondaryLabelColor
        punctColor      = .tertiaryLabelColor
        boldColor       = .labelColor
        listMarkerColor = .controlAccentColor
    }
}

// MARK: - Highlighter

final class MarkdownHighlighter: NSObject, NSTextStorageDelegate {

    private let theme = MarkdownTheme.default
    private var isHighlighting = false

    // Pre-compiled regexes (compiled once, reused on every keystroke)
    private static let fencedCodeRegex = try? NSRegularExpression(pattern: #"^```[\s\S]*?^```"#, options: [.anchorsMatchLines])
    private static let headersRegex    = try? NSRegularExpression(pattern: #"^(#{1,6})\s+(.+)$"#, options: [.anchorsMatchLines])
    private static let blockquoteRegex = try? NSRegularExpression(pattern: #"^>\s?(.*)$"#, options: [.anchorsMatchLines])
    private static let listMarkerRegex = try? NSRegularExpression(pattern: #"^(\s*(?:[-*+]|\d+\.)\s)"#, options: [.anchorsMatchLines])
    private static let hrRegex         = try? NSRegularExpression(pattern: #"^(?:---|\*\*\*|___)\s*$"#, options: [.anchorsMatchLines])
    private static let boldRegex       = try? NSRegularExpression(pattern: #"\*\*(.+?)\*\*|__(.+?)__"#)
    private static let italicRegex     = try? NSRegularExpression(pattern: #"(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)|(?<!_)_(?!_)(.+?)(?<!_)_(?!_)"#)
    private static let inlineCodeRegex = try? NSRegularExpression(pattern: #"`([^`\n]+)`"#)
    private static let linkRegex       = try? NSRegularExpression(pattern: #"\[([^\]]+)\]\(([^)]+)\)"#)

    // MARK: NSTextStorageDelegate

    func textStorage(
        _ textStorage: NSTextStorage,
        didProcessEditing editedMask: NSTextStorageEditActions,
        range editedRange: NSRange,
        changeInLength delta: Int
    ) {
        guard editedMask.contains(.editedCharacters), !isHighlighting else { return }
        isHighlighting = true
        highlight(textStorage)
        isHighlighting = false
    }

    // MARK: - Full-document highlight (called on initial load too)

    func highlight(_ storage: NSTextStorage) {
        let str = storage.string
        let full = NSRange(str.startIndex..., in: str)

        storage.beginEditing()

        // Reset to base style
        storage.setAttributes([
            .font: theme.body,
            .foregroundColor: theme.textColor
        ], range: full)

        // Order matters: broader patterns first, then inline
        applyFencedCodeBlocks(storage, str: str)
        applyHeaders(storage, str: str)
        applyBlockquotes(storage, str: str)
        applyListMarkers(storage, str: str)
        applyHorizontalRules(storage, str: str)
        applyBold(storage, str: str)
        applyItalic(storage, str: str)
        applyInlineCode(storage, str: str)
        applyLinks(storage, str: str)

        storage.endEditing()
    }

    // MARK: - Block: Fenced code blocks

    private func applyFencedCodeBlocks(_ storage: NSTextStorage, str: String) {
        guard let regex = Self.fencedCodeRegex else { return }
        let full = NSRange(str.startIndex..., in: str)
        for match in regex.matches(in: str, range: full) {
            storage.addAttributes([
                .font: theme.mono,
                .foregroundColor: theme.codeColor,
                .backgroundColor: theme.codeBg
            ], range: match.range)
        }
    }

    // MARK: - Block: Headers

    private func applyHeaders(_ storage: NSTextStorage, str: String) {
        guard let regex = Self.headersRegex else { return }
        let full = NSRange(str.startIndex..., in: str)
        for match in regex.matches(in: str, range: full) {
            let hashRange = match.range(at: 1)
            let level = (str as NSString).substring(with: hashRange).count
            let font: NSFont
            switch level {
            case 1: font = theme.h1
            case 2: font = theme.h2
            case 3: font = theme.h3
            default: font = theme.hN
            }
            storage.addAttributes([
                .font: font,
                .foregroundColor: theme.headerColor
            ], range: match.range)
            // Dim the # punctuation
            storage.addAttribute(.foregroundColor, value: theme.punctColor, range: hashRange)
        }
    }

    // MARK: - Block: Blockquotes

    private func applyBlockquotes(_ storage: NSTextStorage, str: String) {
        guard let regex = Self.blockquoteRegex else { return }
        let full = NSRange(str.startIndex..., in: str)
        for match in regex.matches(in: str, range: full) {
            storage.addAttributes([
                .foregroundColor: theme.quoteColor,
                .obliqueness: 0.15
            ], range: match.range)
        }
    }

    // MARK: - Block: List markers

    private func applyListMarkers(_ storage: NSTextStorage, str: String) {
        guard let regex = Self.listMarkerRegex else { return }
        let full = NSRange(str.startIndex..., in: str)
        for match in regex.matches(in: str, range: full) {
            storage.addAttribute(.foregroundColor, value: theme.listMarkerColor, range: match.range(at: 1))
        }
    }

    // MARK: - Block: Horizontal rules

    private func applyHorizontalRules(_ storage: NSTextStorage, str: String) {
        guard let regex = Self.hrRegex else { return }
        let full = NSRange(str.startIndex..., in: str)
        for match in regex.matches(in: str, range: full) {
            storage.addAttribute(.foregroundColor, value: theme.punctColor, range: match.range)
        }
    }

    // MARK: - Inline: Bold

    private func applyBold(_ storage: NSTextStorage, str: String) {
        guard let regex = Self.boldRegex else { return }
        let full = NSRange(str.startIndex..., in: str)
        for match in regex.matches(in: str, range: full) {
            let boldFont = NSFontManager.shared.convert(theme.body, toHaveTrait: .boldFontMask)
            storage.addAttributes([
                .font: boldFont,
                .foregroundColor: theme.boldColor
            ], range: match.range)
            // Dim the ** delimiters
            storage.addAttribute(.foregroundColor, value: theme.punctColor, range: NSRange(location: match.range.location, length: 2))
            storage.addAttribute(.foregroundColor, value: theme.punctColor, range: NSRange(location: match.range.upperBound - 2, length: 2))
        }
    }

    // MARK: - Inline: Italic

    private func applyItalic(_ storage: NSTextStorage, str: String) {
        guard let regex = Self.italicRegex else { return }
        let full = NSRange(str.startIndex..., in: str)
        for match in regex.matches(in: str, range: full) {
            let italicFont = NSFontManager.shared.convert(theme.body, toHaveTrait: .italicFontMask)
            storage.addAttribute(.font, value: italicFont, range: match.range)
            storage.addAttribute(.foregroundColor, value: theme.punctColor, range: NSRange(location: match.range.location, length: 1))
            storage.addAttribute(.foregroundColor, value: theme.punctColor, range: NSRange(location: match.range.upperBound - 1, length: 1))
        }
    }

    // MARK: - Inline: Code

    private func applyInlineCode(_ storage: NSTextStorage, str: String) {
        guard let regex = Self.inlineCodeRegex else { return }
        let full = NSRange(str.startIndex..., in: str)
        for match in regex.matches(in: str, range: full) {
            storage.addAttributes([
                .font: theme.mono,
                .foregroundColor: theme.codeColor,
                .backgroundColor: theme.codeBg
            ], range: match.range)
        }
    }

    // MARK: - Inline: Links

    private func applyLinks(_ storage: NSTextStorage, str: String) {
        guard let regex = Self.linkRegex else { return }
        let full = NSRange(str.startIndex..., in: str)
        for match in regex.matches(in: str, range: full) {
            // Dim brackets and parens
            storage.addAttribute(.foregroundColor, value: theme.punctColor, range: match.range)
            // Color the link text
            if match.numberOfRanges > 1 {
                storage.addAttribute(.foregroundColor, value: theme.linkColor, range: match.range(at: 1))
            }
        }
    }
}
