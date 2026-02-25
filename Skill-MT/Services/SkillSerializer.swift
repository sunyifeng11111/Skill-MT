import Foundation

enum SkillSerializer {

    /// Serialize a `SkillFrontmatter` and markdown body into a complete SKILL.md string.
    static func serialize(frontmatter: SkillFrontmatter, markdownContent: String) -> String {
        var lines: [String] = ["---"]

        if let name = frontmatter.name, !name.isEmpty {
            lines.append("name: \(yamlString(name))")
        }
        if let description = frontmatter.description, !description.isEmpty {
            lines.append("description: \(yamlString(description))")
        }
        if let hint = frontmatter.argumentHint, !hint.isEmpty {
            lines.append("argument-hint: \(yamlString(hint))")
        }
        // Booleans: only emit when they differ from their defaults
        if frontmatter.disableModelInvocation {
            lines.append("disable-model-invocation: true")
        }
        if !frontmatter.userInvocable {
            lines.append("user-invocable: false")
        }
        if let tools = frontmatter.allowedTools, !tools.isEmpty {
            lines.append("allowed-tools: \(tools)")
        }
        if let model = frontmatter.model, !model.isEmpty {
            lines.append("model: \(yamlString(model))")
        }
        if let context = frontmatter.context, !context.isEmpty {
            lines.append("context: \(yamlString(context))")
        }
        if let agent = frontmatter.agent, !agent.isEmpty {
            lines.append("agent: \(yamlString(agent))")
        }
        if let hooksRaw = frontmatter.hooksRaw, !hooksRaw.isEmpty {
            // Emit the raw hooks YAML as an indented block under the `hooks:` key
            let trimmed = hooksRaw.trimmingCharacters(in: .newlines)
            lines.append("hooks:")
            for hookLine in trimmed.components(separatedBy: "\n") {
                lines.append("  \(hookLine)")
            }
        }

        lines.append("---")
        lines.append("")

        let trimmedBody = markdownContent.trimmingCharacters(in: .newlines)
        if !trimmedBody.isEmpty {
            lines.append(trimmedBody)
            lines.append("")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - YAML string quoting

    /// Wraps the value in double quotes if it contains characters that could confuse a YAML
    /// parser; otherwise returns it unchanged.
    static func yamlString(_ s: String) -> String {
        guard !s.isEmpty else { return "\"\"" }

        // Bare scalars that YAML would reinterpret
        let reserved: Set<String> = ["true", "false", "yes", "no", "null", "~"]
        if reserved.contains(s.lowercased()) {
            return quote(s)
        }

        // Leading characters that trigger special YAML semantics
        let specialLeading = CharacterSet(charactersIn: "{}[]|>&!?@`%*#:")
        if let first = s.unicodeScalars.first, specialLeading.contains(first) {
            return quote(s)
        }

        // Internal sequences that break plain scalars
        if s.contains(": ") || s.contains("\n") || s.hasPrefix(" ") || s.hasSuffix(" ") {
            return quote(s)
        }

        return s
    }

    private static func quote(_ s: String) -> String {
        let escaped = s
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }
}
