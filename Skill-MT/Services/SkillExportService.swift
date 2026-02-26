import Foundation

// MARK: - Error Types

enum SkillExportError: LocalizedError {
    case archiveFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .archiveFailed(let e):
            return "Export failed: \(e.localizedDescription)"
        }
    }
}

// MARK: - Service

struct SkillExportService {

    /// Create a ZIP archive from a skill directory.
    ///
    /// Result: `<destinationZipURL>`
    func export(_ skill: Skill, to destinationZipURL: URL) throws {
        let resolvedSource = skill.directoryURL.resolvingSymlinksInPath()
        if FileManager.default.fileExists(atPath: destinationZipURL.path) {
            do {
                try FileManager.default.removeItem(at: destinationZipURL)
            } catch {
                throw SkillExportError.archiveFailed(underlying: error)
            }
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-c", "-k", "--keepParent", resolvedSource.path, destinationZipURL.path]

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw SkillExportError.archiveFailed(underlying: error)
        }

        guard process.terminationStatus == 0 else {
            throw SkillExportError.archiveFailed(
                underlying: NSError(
                    domain: "SkillExport",
                    code: Int(process.terminationStatus),
                    userInfo: [NSLocalizedDescriptionKey: "ditto exited with status \(process.terminationStatus)"]
                )
            )
        }
    }
}
