import Foundation

enum SkillLocation: Hashable {
    case personal
    case project(path: String)
    case legacyCommand(path: String)
    case plugin(id: String, name: String, skillsURL: String)

    var displayName: String {
        switch self {
        case .personal:
            return String(localized: "Personal")
        case .project(let path):
            let name = URL(fileURLWithPath: path).lastPathComponent
            return String(localized: "Project: \(name)")
        case .legacyCommand:
            return String(localized: "Legacy Command")
        case .plugin(_, let name, _):
            return name
        }
    }

    var isPlugin: Bool {
        if case .plugin = self { return true }
        return false
    }

    var basePath: URL {
        switch self {
        case .personal:
            return FileSystemPaths.personalSkillsURL
        case .project(let path):
            return URL(fileURLWithPath: path)
                .appendingPathComponent(".claude")
                .appendingPathComponent("skills")
        case .legacyCommand(let path):
            return URL(fileURLWithPath: path)
        case .plugin(_, _, let skillsURL):
            return URL(fileURLWithPath: skillsURL)
        }
    }
}

// MARK: - Centralized path constants

enum FileSystemPaths {
    static var homeURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
    }

    static var claudeURL: URL {
        homeURL.appendingPathComponent(".claude")
    }

    static var personalSkillsURL: URL {
        claudeURL.appendingPathComponent("skills")
    }

    static var legacyCommandsURL: URL {
        claudeURL.appendingPathComponent("commands")
    }
}
