import Foundation

// MARK: - Error Types

enum SkillImportError: LocalizedError {
    case missingSkillFile
    case parseError(underlying: Error)
    case noSourceDirectory
    case nameConflict(name: String)
    case writeFailed(underlying: Error)
    case extractionFailed(underlying: Error)
    case invalidArchive

    var errorDescription: String? {
        switch self {
        case .missingSkillFile:
            return "Selected folder does not contain a SKILL.md file"
        case .parseError(let e):
            return "Failed to parse SKILL.md: \(e.localizedDescription)"
        case .noSourceDirectory:
            return "No source directory in package"
        case .nameConflict(let name):
            return "A skill named \"\(name)\" already exists at that location"
        case .writeFailed(let e):
            return "Failed to copy skill: \(e.localizedDescription)"
        case .extractionFailed(let e):
            return "Failed to extract ZIP: \(e.localizedDescription)"
        case .invalidArchive:
            return "ZIP archive does not contain a valid skill (missing SKILL.md)"
        }
    }
}

// MARK: - Service

struct SkillImportService {

    // MARK: - ZIP Extraction

    private func extractZIP(_ zipURL: URL) throws -> URL {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("skill-import-\(UUID().uuidString)")

        do {
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        } catch {
            throw SkillImportError.extractionFailed(underlying: error)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-xk", zipURL.path, tempDir.path]

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw SkillImportError.extractionFailed(underlying: error)
        }

        guard process.terminationStatus == 0 else {
            throw SkillImportError.extractionFailed(
                underlying: NSError(domain: "SkillImport", code: Int(process.terminationStatus),
                                    userInfo: [NSLocalizedDescriptionKey: "ditto exited with status \(process.terminationStatus)"])
            )
        }

        // Find the directory containing SKILL.md
        let fm = FileManager.default
        if fm.fileExists(atPath: tempDir.appendingPathComponent("SKILL.md").path) {
            return tempDir
        }

        let contents = (try? fm.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: [.isDirectoryKey])) ?? []
        let subdirs = contents.filter {
            (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        }
        if subdirs.count == 1,
           fm.fileExists(atPath: subdirs[0].appendingPathComponent("SKILL.md").path) {
            return subdirs[0]
        }

        throw SkillImportError.invalidArchive
    }

    static func cleanupIfTemporary(_ package: SkillPackage) {
        guard let sourceDir = package.sourceDirectory else { return }
        let tempBase = NSTemporaryDirectory()
        guard sourceDir.path.hasPrefix(tempBase) else { return }
        // Walk up to find the skill-import-* directory under temp
        var candidate = sourceDir
        while candidate.path != tempBase && !candidate.path.isEmpty {
            let parent = candidate.deletingLastPathComponent()
            if parent.path == tempBase {
                try? FileManager.default.removeItem(at: candidate)
                return
            }
            candidate = parent
        }
    }

    // MARK: - Phase 1: Preview

    /// Read a skill directory (or ZIP archive) and return a preview package (nothing is copied yet).
    func preview(from url: URL) throws -> SkillPackage {
        let directoryURL: URL
        if url.pathExtension.lowercased() == "zip" {
            directoryURL = try extractZIP(url)
        } else {
            directoryURL = url
        }
        let skillFileURL = directoryURL.appendingPathComponent("SKILL.md")
        guard FileManager.default.fileExists(atPath: skillFileURL.path) else {
            throw SkillImportError.missingSkillFile
        }

        let raw: String
        do {
            raw = try String(contentsOf: skillFileURL, encoding: .utf8)
        } catch {
            throw SkillImportError.parseError(underlying: error)
        }

        let frontmatter: SkillFrontmatter
        let markdown: String
        do {
            (frontmatter, markdown) = try SkillParser.parse(content: raw)
        } catch {
            throw SkillImportError.parseError(underlying: error)
        }

        let supporting = (try? FileSystemService().enumerateSupportingFiles(in: directoryURL)) ?? []

        return SkillPackage(
            name: directoryURL.lastPathComponent,
            frontmatter: frontmatter,
            markdownContent: markdown,
            supportingFiles: supporting,
            sourceDirectory: directoryURL
        )
    }

    // MARK: - Phase 2: Commit

    /// Copy the previewed skill folder to its final location.
    ///
    /// - Parameters:
    ///   - package: The package returned by `preview(from:)`.
    ///   - name: Desired directory name at the target (may differ from the source name).
    ///   - location: Where to install the skill.
    /// - Returns: URL of the newly-created skill directory.
    @discardableResult
    func commit(_ package: SkillPackage, name: String, location: SkillLocation) throws -> URL {
        guard let sourceDir = package.sourceDirectory else {
            throw SkillImportError.noSourceDirectory
        }

        let targetBase = location.basePath
        let targetDir  = targetBase.appendingPathComponent(name)

        guard !FileManager.default.fileExists(atPath: targetDir.path) else {
            throw SkillImportError.nameConflict(name: name)
        }

        do {
            try FileManager.default.createDirectory(at: targetBase, withIntermediateDirectories: true)
        } catch {
            throw SkillImportError.writeFailed(underlying: error)
        }

        do {
            try FileManager.default.copyItem(at: sourceDir, to: targetDir)
        } catch {
            throw SkillImportError.writeFailed(underlying: error)
        }

        return targetDir
    }
}
