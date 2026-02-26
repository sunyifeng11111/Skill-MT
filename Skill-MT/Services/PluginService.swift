import Foundation

struct InstalledPlugin {
    let id: String       // e.g. "everything-claude-code@everything-claude-code"
    let name: String     // e.g. "everything-claude-code"
    let skillsURL: URL
}

struct PluginService {

    private let settings: AppSettings

    init(settings: AppSettings = .shared) {
        self.settings = settings
    }

    private var pluginsJSONURL: URL {
        FileSystemPaths.claudeURL(settings: settings)
            .appendingPathComponent("plugins")
            .appendingPathComponent("installed_plugins.json")
    }

    func discoverPlugins() -> [InstalledPlugin] {
        guard let data = try? Data(contentsOf: pluginsJSONURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let plugins = json["plugins"] as? [String: [[String: Any]]]
        else { return [] }

        var result: [InstalledPlugin] = []
        for (pluginId, entries) in plugins {
            guard let entry = entries.first,
                  let installPath = entry["installPath"] as? String
            else { continue }

            let skillsURL = URL(fileURLWithPath: installPath).appendingPathComponent("skills")
            guard FileManager.default.fileExists(atPath: skillsURL.path) else { continue }

            // Derive a human-readable name from the plugin id (before the @)
            let name = pluginId.components(separatedBy: "@").first ?? pluginId
            result.append(InstalledPlugin(id: pluginId, name: name, skillsURL: skillsURL))
        }
        return result.sorted { $0.name < $1.name }
    }

    func discoverSkills(for plugin: InstalledPlugin) -> [Skill] {
        let location = SkillLocation.plugin(id: plugin.id, name: plugin.name,
                                            skillsURL: plugin.skillsURL.path)
        return (try? FileSystemService().discoverSkills(in: plugin.skillsURL, location: location)) ?? []
    }
}
