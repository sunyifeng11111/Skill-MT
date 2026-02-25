import Foundation

struct Skill: Identifiable, Hashable {
    let id: UUID
    /// Directory name derived from the skill folder, or filename for legacy commands.
    var name: String
    var frontmatter: SkillFrontmatter
    /// Markdown body after the frontmatter block.
    var markdownContent: String
    var location: SkillLocation
    /// The skill's containing directory (or the commands directory for legacy commands).
    var directoryURL: URL
    var supportingFiles: [SkillFile]
    var lastModified: Date
    var isLegacyCommand: Bool
    var isEnabled: Bool

    init(
        id: UUID = UUID(),
        name: String,
        frontmatter: SkillFrontmatter,
        markdownContent: String,
        location: SkillLocation,
        directoryURL: URL,
        supportingFiles: [SkillFile] = [],
        lastModified: Date = Date(),
        isLegacyCommand: Bool = false,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.frontmatter = frontmatter
        self.markdownContent = markdownContent
        self.location = location
        self.directoryURL = directoryURL
        self.supportingFiles = supportingFiles
        self.lastModified = lastModified
        self.isLegacyCommand = isLegacyCommand
        self.isEnabled = isEnabled
    }

    /// Preferred display name: uses `frontmatter.name` when set, falls back to directory name.
    var displayName: String {
        frontmatter.name ?? name
    }

    /// URL to the SKILL.md file (or the .md file for legacy commands).
    var skillFileURL: URL {
        if isLegacyCommand {
            let ext = isEnabled ? "md" : "md.disabled"
            return directoryURL.appendingPathComponent("\(name).\(ext)")
        }
        return directoryURL.appendingPathComponent(isEnabled ? "SKILL.md" : "SKILL.md.disabled")
    }
}
