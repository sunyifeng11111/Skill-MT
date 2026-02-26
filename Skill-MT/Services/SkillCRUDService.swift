import Foundation

// MARK: - Error Types

enum SkillCRUDError: LocalizedError {
    case invalidName(reason: String)
    case directoryAlreadyExists(path: String)
    case writeFailed(path: String, underlying: Error)
    case deleteFailed(path: String, underlying: Error)
    case unsafeDeletePath(path: String)

    var errorDescription: String? {
        switch self {
        case .invalidName(let reason):
            return "Invalid skill name: \(reason)"
        case .directoryAlreadyExists(let path):
            return "A skill already exists at: \(URL(fileURLWithPath: path).lastPathComponent)"
        case .writeFailed(let path, let error):
            return "Failed to write \(URL(fileURLWithPath: path).lastPathComponent): \(error.localizedDescription)"
        case .deleteFailed(let path, let error):
            return "Failed to delete \(URL(fileURLWithPath: path).lastPathComponent): \(error.localizedDescription)"
        case .unsafeDeletePath(let path):
            return "Cannot delete path outside Claude directory: \(path)"
        }
    }
}

// MARK: - Service

final class SkillCRUDService {

    private let fileManager: FileManager
    private let settings: AppSettings

    init(fileManager: FileManager = .default, settings: AppSettings = .shared) {
        self.fileManager = fileManager
        self.settings = settings
    }

    // MARK: - Create

    /// Create a new skill directory and `SKILL.md` at `location`.
    /// - Returns: URL of the newly-created skill directory.
    @discardableResult
    func createSkill(
        name: String,
        frontmatter: SkillFrontmatter,
        markdownContent: String,
        location: SkillLocation
    ) throws -> URL {
        try validateName(name)

        let targetDir = location.basePath.appendingPathComponent(name)

        guard !fileManager.fileExists(atPath: targetDir.path) else {
            throw SkillCRUDError.directoryAlreadyExists(path: targetDir.path)
        }

        do {
            try fileManager.createDirectory(at: targetDir, withIntermediateDirectories: true)
        } catch {
            throw SkillCRUDError.writeFailed(path: targetDir.path, underlying: error)
        }

        let content = SkillSerializer.serialize(frontmatter: frontmatter, markdownContent: markdownContent)
        let skillFile = targetDir.appendingPathComponent("SKILL.md")
        do {
            try content.write(to: skillFile, atomically: true, encoding: .utf8)
        } catch {
            try? fileManager.removeItem(at: targetDir) // clean up on write failure
            throw SkillCRUDError.writeFailed(path: skillFile.path, underlying: error)
        }

        return targetDir
    }

    // MARK: - Update

    /// Overwrite the `SKILL.md` of an existing skill with new content.
    func updateSkill(
        _ skill: Skill,
        newFrontmatter: SkillFrontmatter,
        newMarkdownContent: String
    ) throws {
        let content = SkillSerializer.serialize(frontmatter: newFrontmatter, markdownContent: newMarkdownContent)
        do {
            try content.write(to: skill.skillFileURL, atomically: true, encoding: .utf8)
        } catch {
            throw SkillCRUDError.writeFailed(path: skill.skillFileURL.path, underlying: error)
        }
    }

    // MARK: - Enable / Disable

    func setSkillEnabled(_ skill: Skill, enabled: Bool) throws {
        guard skill.isEnabled != enabled else { return }
        let currentURL = skill.skillFileURL
        let targetURL: URL
        if skill.isLegacyCommand {
            let filename = enabled ? "\(skill.name).md" : "\(skill.name).md.disabled"
            targetURL = skill.directoryURL.appendingPathComponent(filename)
        } else {
            targetURL = skill.directoryURL.appendingPathComponent(
                enabled ? "SKILL.md" : "SKILL.md.disabled"
            )
        }
        try assertSafePath(currentURL, skill: skill)
        do {
            try fileManager.moveItem(at: currentURL, to: targetURL)
        } catch {
            throw SkillCRUDError.writeFailed(path: targetURL.path, underlying: error)
        }
    }

    // MARK: - Delete

    /// Remove the skill directory (or the single `.md` file for legacy commands).
    func deleteSkill(_ skill: Skill) throws {
        let target: URL = skill.isLegacyCommand ? skill.skillFileURL : skill.directoryURL
        try assertSafePath(target, skill: skill)
        do {
            try fileManager.removeItem(at: target)
        } catch {
            throw SkillCRUDError.deleteFailed(path: target.path, underlying: error)
        }
    }

    // MARK: - Validation

    private func validateName(_ name: String) throws {
        guard !name.isEmpty else {
            throw SkillCRUDError.invalidName(reason: "Name cannot be empty")
        }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        guard name.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
            throw SkillCRUDError.invalidName(reason: "Only letters, numbers, hyphens, and underscores are allowed")
        }
    }

    private func assertSafePath(_ url: URL, skill: Skill) throws {
        let path = url.path
        let safe: Bool
        switch skill.location {
        case .personal:
            safe = path.hasPrefix(FileSystemPaths.personalSkillsURL(settings: settings).path)
        case .codexPersonal:
            safe = path.hasPrefix(FileSystemPaths.codexSkillsURL(settings: settings).path)
        case .codexSystem(let path):
            safe = url.path.hasPrefix(path)
        case .project:
            safe = path.hasPrefix(skill.location.basePath.path)
        case .legacyCommand:
            safe = path.hasPrefix(FileSystemPaths.legacyCommandsURL(settings: settings).path)
        case .plugin(_, _, let skillsURL):
            safe = path.hasPrefix(skillsURL)
        }
        guard safe else {
            throw SkillCRUDError.unsafeDeletePath(path: path)
        }
    }
}
