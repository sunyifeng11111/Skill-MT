import Foundation

enum SkillLocation: Hashable {
    case personal
    case codexPersonal
    case codexSystem(path: String)
    case project(path: String)
    case legacyCommand(path: String)
    case plugin(id: String, name: String, skillsURL: String)

    var displayName: String {
        switch self {
        case .personal:
            return String(localized: "Personal")
        case .codexPersonal:
            return String(localized: "Personal")
        case .codexSystem:
            return String(localized: "System Skill")
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

    var isReadOnly: Bool {
        switch self {
        case .plugin, .codexSystem:
            return true
        default:
            return false
        }
    }

    var basePath: URL {
        switch self {
        case .personal:
            return FileSystemPaths.personalSkillsURL
        case .codexPersonal:
            return FileSystemPaths.codexSkillsURL
        case .codexSystem(let path):
            return URL(fileURLWithPath: path)
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
    static var homeURL: URL { FileManager.default.homeDirectoryForCurrentUser }

    static var defaultClaudeHomeURL: URL { homeURL.appendingPathComponent(".claude") }
    static var defaultCodexHomeURL: URL { homeURL.appendingPathComponent(".codex") }

    static func claudeURL(settings: AppSettings = .shared) -> URL {
        let path = settings.claudeHomePath.isEmpty
            ? defaultClaudeHomeURL.path
            : settings.claudeHomePath
        return URL(fileURLWithPath: path)
    }

    static func personalSkillsURL(settings: AppSettings = .shared) -> URL {
        claudeURL(settings: settings).appendingPathComponent("skills")
    }

    static func legacyCommandsURL(settings: AppSettings = .shared) -> URL {
        claudeURL(settings: settings).appendingPathComponent("commands")
    }

    static func codexURL(settings: AppSettings = .shared) -> URL {
        let path = settings.codexHomePath.isEmpty
            ? defaultCodexHomeURL.path
            : settings.codexHomePath
        return URL(fileURLWithPath: path)
    }

    static func codexSkillsURL(settings: AppSettings = .shared) -> URL {
        codexURL(settings: settings).appendingPathComponent("skills")
    }

    static func codexSystemSkillsURL(settings: AppSettings = .shared) -> URL {
        codexSkillsURL(settings: settings).appendingPathComponent(".system")
    }

    static var claudeURL: URL { claudeURL(settings: .shared) }
    static var personalSkillsURL: URL { personalSkillsURL(settings: .shared) }
    static var legacyCommandsURL: URL { legacyCommandsURL(settings: .shared) }
    static var codexURL: URL { codexURL(settings: .shared) }
    static var codexSkillsURL: URL { codexSkillsURL(settings: .shared) }
    static var codexSystemSkillsURL: URL { codexSystemSkillsURL(settings: .shared) }
}
