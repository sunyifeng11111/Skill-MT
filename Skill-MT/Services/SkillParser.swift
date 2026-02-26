import Foundation
import Yams

// MARK: - Error Types

enum SkillParserError: Error, LocalizedError {
    case invalidYAML(underlying: Error)
    case unexpectedFrontmatterType

    var errorDescription: String? {
        switch self {
        case .invalidYAML(let error):
            return "Invalid YAML in frontmatter: \(error.localizedDescription)"
        case .unexpectedFrontmatterType:
            return "Frontmatter YAML must be a key-value mapping, not a scalar or sequence."
        }
    }
}

// MARK: - Parser

enum SkillParser {

    // MARK: - Public API

    /// Parse a SKILL.md or command .md file content into frontmatter + markdown body.
    static func parse(content: String) throws -> (frontmatter: SkillFrontmatter, markdownContent: String) {
        let (yaml, markdown) = splitContent(content)
        guard let yaml else {
            return (.default, markdown)
        }
        // Empty frontmatter block (just ---)
        let trimmed = yaml.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return (.default, markdown)
        }
        let frontmatter = try parseFrontmatter(yaml: yaml)
        return (frontmatter, markdown)
    }

    /// Extract the YAML frontmatter block and the markdown body from raw file content.
    /// Returns `(yamlString?, markdownBody)`.
    static func splitContent(_ content: String) -> (yaml: String?, markdown: String) {
        // Normalise line endings
        let normalised = content.replacingOccurrences(of: "\r\n", with: "\n")

        // Must start with the opening delimiter (optionally preceded by a BOM)
        let stripped = normalised.hasPrefix("\u{FEFF}") ? String(normalised.dropFirst()) : normalised
        guard stripped.hasPrefix("---\n") || stripped == "---" else {
            return (nil, normalised)
        }

        // Find the closing --- delimiter (must be on its own line)
        // Search starts after the opening delimiter
        let afterOpen = String(stripped.dropFirst(4)) // drop "---\n"
        guard let closeRange = findClosingDelimiter(in: afterOpen) else {
            // No closing delimiter found — treat entire content as markdown
            return (nil, normalised)
        }

        let yaml = String(afterOpen[afterOpen.startIndex ..< closeRange.lowerBound])
        var markdown = String(afterOpen[closeRange.upperBound...])
        // Trim a single leading newline after the closing delimiter
        if markdown.hasPrefix("\n") {
            markdown = String(markdown.dropFirst())
        }
        return (yaml, markdown)
    }

    /// Parse a raw YAML string into a `SkillFrontmatter`.
    static func parseFrontmatter(yaml: String) throws -> SkillFrontmatter {
        let node: Any
        do {
            guard let loaded = try Yams.load(yaml: yaml) else {
                return .default
            }
            node = loaded
        } catch {
            throw SkillParserError.invalidYAML(underlying: error)
        }

        guard let dict = node as? [String: Any] else {
            throw SkillParserError.unexpectedFrontmatterType
        }

        // --- hooks: serialise back to raw YAML string ---
        var hooksRaw: String?
        if let hooksValue = dict["hooks"] {
            hooksRaw = (try? Yams.dump(object: hooksValue)) ?? "\(hooksValue)"
        }

        return SkillFrontmatter(
            name:                     string(from: dict["name"]),
            description:              string(from: dict["description"]),
            argumentHint:             string(from: dict["argument-hint"]),
            disableModelInvocation:   bool(from: dict["disable-model-invocation"]) ?? false,
            userInvocable:            bool(from: dict["user-invocable"]) ?? true,
            allowedTools:             string(from: dict["allowed-tools"]),
            model:                    string(from: dict["model"]),
            context:                  string(from: dict["context"]),
            agent:                    string(from: dict["agent"]),
            hooksRaw:                 hooksRaw
        )
    }

    // MARK: - Internal Helpers

    /// Find the closing `---` delimiter within `content`, returning the range that covers
    /// `---\n` (or `---` at end-of-string). Handles the delimiter at any line start.
    private static func findClosingDelimiter(in content: String) -> Range<String.Index>? {
        // Match "---" at the start of a line, followed by \n or end-of-string
        var searchStart = content.startIndex
        while searchStart < content.endIndex {
            // Find next occurrence of "---"
            guard let range = content.range(of: "---", range: searchStart ..< content.endIndex) else {
                return nil
            }

            // Verify it is at the start of a line
            let isLineStart = range.lowerBound == content.startIndex
                || content[content.index(before: range.lowerBound)] == "\n"

            if isLineStart {
                // Determine the end of the delimiter line
                let afterDelimiter = range.upperBound
                if afterDelimiter == content.endIndex {
                    // --- at very end of string
                    return range.lowerBound ..< content.endIndex
                }
                if content[afterDelimiter] == "\n" {
                    // --- followed by newline — this is our closing delimiter
                    let lineEnd = content.index(after: afterDelimiter)
                    return range.lowerBound ..< lineEnd
                }
                // --- followed by something else (e.g. ---more) — not a valid delimiter
            }
            searchStart = content.index(after: range.lowerBound)
        }
        return nil
    }

    /// Coerce a Yams-decoded value to `Bool`, handling `true`/`false`/`yes`/`no`/`1`/`0`.
    private static func bool(from value: Any?) -> Bool? {
        switch value {
        case let b as Bool:
            return b
        case let s as String:
            switch s.lowercased() {
            case "true", "yes", "1": return true
            case "false", "no", "0": return false
            default: return nil
            }
        case let i as Int:
            return i != 0
        default:
            return nil
        }
    }

    /// Coerce a Yams-decoded scalar value to String, preserving legacy files where
    /// YAML implicit typing may decode unquoted text as non-String.
    private static func string(from value: Any?) -> String? {
        switch value {
        case let s as String:
            return s
        case let b as Bool:
            return b ? "true" : "false"
        case let i as Int:
            return String(i)
        case let d as Double:
            return String(d)
        case let f as Float:
            return String(f)
        case let n as NSNumber:
            return n.stringValue
        default:
            return nil
        }
    }
}
