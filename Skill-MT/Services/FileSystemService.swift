import Foundation

// MARK: - Error Types

enum FileSystemServiceError: Error, LocalizedError {
    case directoryNotFound(path: String)
    case fileReadFailed(path: String, underlying: Error)
    case skillFileNotFound(directory: String)
    case unreadableContent(path: String)

    var errorDescription: String? {
        switch self {
        case .directoryNotFound(let path):
            return "Directory not found: \(path)"
        case .fileReadFailed(let path, let error):
            return "Failed to read file at \(path): \(error.localizedDescription)"
        case .skillFileNotFound(let dir):
            return "No SKILL.md found in directory: \(dir)"
        case .unreadableContent(let path):
            return "File content is not valid UTF-8: \(path)"
        }
    }
}

// MARK: - Protocol (enables mocking in tests)

protocol FileSystemServiceProtocol {
    func discoverSkills(in baseURL: URL, location: SkillLocation) throws -> [Skill]
    func discoverLegacyCommands(in baseURL: URL) throws -> [Skill]
    func readSkill(at directoryURL: URL, location: SkillLocation) throws -> Skill
    func enumerateSupportingFiles(in directoryURL: URL) throws -> [SkillFile]
}

// MARK: - Implementation

final class FileSystemService: FileSystemServiceProtocol {

    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    // MARK: - Convenience (uses real ~/.claude paths)

    func discoverPersonalSkills() throws -> [Skill] {
        try discoverSkills(in: FileSystemPaths.personalSkillsURL, location: .personal)
    }

    func discoverProjectSkills(projectPath: URL) throws -> [Skill] {
        let skillsURL = projectPath
            .appendingPathComponent(".claude")
            .appendingPathComponent("skills")
        return try discoverSkills(in: skillsURL, location: .project(path: projectPath.path))
    }

    func discoverLegacyCommands() throws -> [Skill] {
        try discoverLegacyCommands(in: FileSystemPaths.legacyCommandsURL)
    }

    // MARK: - Protocol Implementation

    /// Discover all skills found as immediate subdirectories of `baseURL`.
    func discoverSkills(in baseURL: URL, location: SkillLocation) throws -> [Skill] {
        guard fileManager.fileExists(atPath: baseURL.path) else {
            return [] // Directory simply doesn't exist yet — not an error
        }

        let subdirectories: [URL]
        do {
            // Use fileExists(atPath:isDirectory:) instead of resourceValues(.isDirectoryKey)
            // because skills may be symlinks to directories; resourceValues does NOT follow
            // symlinks and would return isDirectory=false for them.
            subdirectories = try fileManager.contentsOfDirectory(
                at: baseURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ).filter { url in
                var isDir: ObjCBool = false
                fileManager.fileExists(atPath: url.path, isDirectory: &isDir)
                return isDir.boolValue
            }
        } catch {
            throw FileSystemServiceError.directoryNotFound(path: baseURL.path)
        }

        var skills: [Skill] = []
        for subdir in subdirectories {
            do {
                let skill = try readSkill(at: subdir, location: location)
                skills.append(skill)
            } catch {
                // Individual parse failures do not abort the whole scan
                continue
            }
        }
        return skills
    }

    /// Discover legacy command `.md` files in `baseURL` (non-recursive).
    func discoverLegacyCommands(in baseURL: URL) throws -> [Skill] {
        guard fileManager.fileExists(atPath: baseURL.path) else {
            return []
        }

        let files: [URL]
        do {
            files = try fileManager.contentsOfDirectory(
                at: baseURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ).filter { url in
                let ext = url.pathExtension
                let isDisabled = url.lastPathComponent.hasSuffix(".md.disabled")
                let isMd = ext == "md" || isDisabled
                return isMd &&
                    (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) != true
            }
        } catch {
            throw FileSystemServiceError.directoryNotFound(path: baseURL.path)
        }

        var commands: [Skill] = []
        for fileURL in files {
            do {
                let content = try readUTF8(at: fileURL)
                let (frontmatter, markdown) = try SkillParser.parse(content: content)
                let isEnabled = !fileURL.lastPathComponent.hasSuffix(".md.disabled")
                // Strip .md or .md.disabled to get the command name
                let filename = fileURL.lastPathComponent
                let name: String
                if filename.hasSuffix(".md.disabled") {
                    name = String(filename.dropLast(".md.disabled".count))
                } else {
                    name = fileURL.deletingPathExtension().lastPathComponent
                }
                let modified = modificationDate(of: fileURL)

                let skill = Skill(
                    name: name,
                    frontmatter: frontmatter,
                    markdownContent: markdown,
                    location: .legacyCommand(path: baseURL.path),
                    directoryURL: baseURL,
                    supportingFiles: [],
                    lastModified: modified,
                    isLegacyCommand: true,
                    isEnabled: isEnabled
                )
                commands.append(skill)
            } catch {
                continue
            }
        }
        return commands
    }

    /// Read and parse the SKILL.md (or SKILL.md.disabled) inside `directoryURL`.
    func readSkill(at directoryURL: URL, location: SkillLocation) throws -> Skill {
        let enabledURL  = directoryURL.appendingPathComponent("SKILL.md")
        let disabledURL = directoryURL.appendingPathComponent("SKILL.md.disabled")

        let (skillFileURL, isEnabled): (URL, Bool)
        if fileManager.fileExists(atPath: enabledURL.path) {
            (skillFileURL, isEnabled) = (enabledURL, true)
        } else if fileManager.fileExists(atPath: disabledURL.path) {
            (skillFileURL, isEnabled) = (disabledURL, false)
        } else {
            throw FileSystemServiceError.skillFileNotFound(directory: directoryURL.path)
        }

        let content: String
        do {
            content = try readUTF8(at: skillFileURL)
        } catch {
            throw FileSystemServiceError.fileReadFailed(path: skillFileURL.path, underlying: error)
        }

        let (frontmatter, markdown) = try SkillParser.parse(content: content)
        let name = directoryURL.lastPathComponent
        let modified = modificationDate(of: skillFileURL)
        let supporting = (try? enumerateSupportingFiles(in: directoryURL)) ?? []

        return Skill(
            name: name,
            frontmatter: frontmatter,
            markdownContent: markdown,
            location: location,
            directoryURL: directoryURL,
            supportingFiles: supporting,
            lastModified: modified,
            isLegacyCommand: false,
            isEnabled: isEnabled
        )
    }

    /// List all files inside `directoryURL` except `SKILL.md`, recursively.
    func enumerateSupportingFiles(in directoryURL: URL) throws -> [SkillFile] {
        guard let enumerator = fileManager.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey, .nameKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var files: [SkillFile] = []
        for case let fileURL as URL in enumerator {
            // Skip the SKILL.md itself
            if fileURL.lastPathComponent == "SKILL.md" { continue }

            if let file = try? SkillFile(fileURL: fileURL, relativeTo: directoryURL) {
                files.append(file)
            }
        }
        return files
    }

    // MARK: - Private Helpers

    private func readUTF8(at url: URL) throws -> String {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            throw FileSystemServiceError.unreadableContent(path: url.path)
        }
        return content
    }

    private func modificationDate(of url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date()
    }
}
