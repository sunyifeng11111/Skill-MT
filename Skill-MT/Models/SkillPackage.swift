import Foundation

/// A parsed skill directory that has been previewed but not yet copied to its final location.
struct SkillPackage: Identifiable {
    let id: UUID
    let name: String
    let frontmatter: SkillFrontmatter
    let markdownContent: String
    let supportingFiles: [SkillFile]
    /// The source directory that was picked for import.
    var sourceDirectory: URL?

    init(
        id: UUID = UUID(),
        name: String,
        frontmatter: SkillFrontmatter,
        markdownContent: String,
        supportingFiles: [SkillFile] = [],
        sourceDirectory: URL? = nil
    ) {
        self.id = id
        self.name = name
        self.frontmatter = frontmatter
        self.markdownContent = markdownContent
        self.supportingFiles = supportingFiles
        self.sourceDirectory = sourceDirectory
    }
}
