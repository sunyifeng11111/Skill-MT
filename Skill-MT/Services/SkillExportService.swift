import Foundation

// MARK: - Error Types

enum SkillExportError: LocalizedError {
    case alreadyExists(name: String)
    case copyFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .alreadyExists(let name):
            return "A folder named \"\(name)\" already exists at the destination"
        case .copyFailed(let e):
            return "Export failed: \(e.localizedDescription)"
        }
    }
}

// MARK: - Service

struct SkillExportService {

    /// Copy a skill directory into `destinationDirectory`.
    ///
    /// Result: `destinationDirectory/<skill.name>/`
    func export(_ skill: Skill, to destinationDirectory: URL) throws {
        let resolvedSource = skill.directoryURL.resolvingSymlinksInPath()
        let target = destinationDirectory.appendingPathComponent(skill.name)
        guard !FileManager.default.fileExists(atPath: target.path) else {
            throw SkillExportError.alreadyExists(name: skill.name)
        }
        do {
            try FileManager.default.copyItem(at: resolvedSource, to: target)
        } catch {
            throw SkillExportError.copyFailed(underlying: error)
        }
    }
}
