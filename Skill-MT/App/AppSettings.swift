import Foundation

@Observable
final class AppSettings {

    static let shared = AppSettings()

    private enum Keys {
        static let claudeHomePath = "claudeHomePath"
        static let codexHomePath = "codexHomePath"
    }

    var claudeHomePath: String {
        didSet { defaults.set(claudeHomePath, forKey: Keys.claudeHomePath) }
    }

    var codexHomePath: String {
        didSet { defaults.set(codexHomePath, forKey: Keys.codexHomePath) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let claude = defaults.string(forKey: Keys.claudeHomePath)
            ?? FileSystemPaths.defaultClaudeHomeURL.path
        let codex = defaults.string(forKey: Keys.codexHomePath)
            ?? FileSystemPaths.defaultCodexHomeURL.path

        self.claudeHomePath = Self.normalizedPath(claude)
        self.codexHomePath = Self.normalizedPath(codex)
    }

    func saveClaudeHome(_ path: String) {
        let normalized = Self.normalizedPath(path)
        claudeHomePath = normalized.isEmpty ? FileSystemPaths.defaultClaudeHomeURL.path : normalized
    }

    func saveCodexHome(_ path: String) {
        let normalized = Self.normalizedPath(path)
        codexHomePath = normalized.isEmpty ? FileSystemPaths.defaultCodexHomeURL.path : normalized
    }

    func resetClaudeHome() {
        claudeHomePath = FileSystemPaths.defaultClaudeHomeURL.path
    }

    func resetCodexHome() {
        codexHomePath = FileSystemPaths.defaultCodexHomeURL.path
    }

    func expandedPath(_ path: String) -> URL {
        URL(fileURLWithPath: Self.normalizedPath(path))
    }

    private static func normalizedPath(_ path: String) -> String {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        let expanded = NSString(string: trimmed).expandingTildeInPath
        return URL(fileURLWithPath: expanded).standardizedFileURL.path
    }
}
