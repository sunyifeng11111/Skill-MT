import SwiftUI
import AppKit
import UniformTypeIdentifiers

enum AppStateError: LocalizedError {
    case readOnlySkill

    var errorDescription: String? {
        switch self {
        case .readOnlySkill:
            return "This skill is read-only and cannot be modified."
        }
    }
}

@Observable
final class AppState {

    let settings: AppSettings
    private let updateService = UpdateService()
    private let versionService = AppVersionService()

    // MARK: - Skill Data

    var personalSkills: [Skill] = []
    var codexPersonalSkills: [Skill] = []
    var codexSystemSkills: [Skill] = []
    var legacyCommands: [Skill] = []
    /// project URL path → [Skill]
    var projectSkills: [String: [Skill]] = [:]
    /// project URL path → [Codex project skills]
    var codexProjectSkills: [String: [Skill]] = [:]
    /// plugin id → [Skill]
    var pluginSkills: [String: [Skill]] = [:]
    /// Ordered list of monitored project root paths (persisted)
    var monitoredProjectURLs: [URL] = []
    /// Discovered plugins (read-only, from installed_plugins.json)
    var installedPlugins: [InstalledPlugin] = []

    // MARK: - UI State

    var selectedSkill: Skill?
    var searchText: String = ""
    var settingsRevision: Int = 0
    var isCheckingUpdates: Bool = false
    var latestReleaseInfo: ReleaseInfo?
    var updateStatusMessage: String?
    var showUpdatePrompt: Bool = false
    var pendingDownloadURL: URL?
    var selectedProvider: SkillProvider = .claude {
        didSet {
            UserDefaults.standard.set(selectedProvider.rawValue, forKey: "selectedProvider")
            if selectedProvider == .codex {
                preferredCreateLocation = .codexPersonal
            } else {
                if case .codexPersonal = preferredCreateLocation {
                    preferredCreateLocation = .personal
                }
                if case .codexProject = preferredCreateLocation {
                    preferredCreateLocation = .personal
                }
            }
        }
    }
    /// Preferred target location when opening "Create Skill".
    var preferredCreateLocation: SkillLocation = .personal

    // MARK: - CRUD Sheet State

    var showCreateSheet: Bool = false
    var skillToEdit: Skill?
    var skillToDelete: Skill?

    // MARK: - Import / Export State

    var pendingImportPackage: SkillPackage?
    var showImportSheet: Bool = false
    var showSettingsSheet: Bool = false
    var lastError: String?
    var lastUpdateCheckAt: Date?

    // MARK: - Computed

    var allSkills: [Skill] {
        switch selectedProvider {
        case .claude:
            return personalSkills + legacyCommands
                + projectSkills.values.flatMap { $0 }
                + pluginSkills.values.flatMap { $0 }
        case .codex:
            return codexPersonalSkills + codexSystemSkills + codexProjectSkills.values.flatMap { $0 }
        }
    }

    var filteredPersonalSkills: [Skill] {
        filter(personalSkills)
    }

    var filteredLegacyCommands: [Skill] {
        filter(legacyCommands)
    }

    var filteredCodexPersonalSkills: [Skill] {
        filter(codexPersonalSkills)
    }

    var filteredCodexSystemSkills: [Skill] {
        filter(codexSystemSkills)
    }

    func filteredProjectSkills(for path: String) -> [Skill] {
        filter(projectSkills[path] ?? [])
    }

    func filteredCodexProjectSkills(for path: String) -> [Skill] {
        filter(codexProjectSkills[path] ?? [])
    }

    func filteredPluginSkills(for id: String) -> [Skill] {
        filter(pluginSkills[id] ?? [])
    }

    private func filter(_ skills: [Skill]) -> [Skill] {
        guard !searchText.isEmpty else { return skills }
        let query = searchText.lowercased()
        return skills.filter {
            $0.displayName.lowercased().contains(query) ||
            ($0.frontmatter.description?.lowercased().contains(query) ?? false)
        }
    }

    var localVersion: String {
        versionService.localVersion()
    }

    var latestVersionText: String {
        latestReleaseInfo?.version ?? "-"
    }

    // MARK: - Load

    @MainActor
    func loadAllSkills() async {
        let personalTask = Task.detached(priority: .userInitiated) { () -> [Skill] in
            (try? FileSystemService().discoverPersonalSkills()) ?? []
        }
        let codexPersonalTask = Task.detached(priority: .userInitiated) { () -> [Skill] in
            (try? FileSystemService().discoverCodexPersonalSkills()) ?? []
        }
        let codexSystemTask = Task.detached(priority: .userInitiated) { () -> [Skill] in
            (try? FileSystemService().discoverCodexSystemSkills()) ?? []
        }
        let legacyTask = Task.detached(priority: .userInitiated) { () -> [Skill] in
            (try? FileSystemService().discoverLegacyCommands()) ?? []
        }

        personalSkills = await personalTask.value
        codexPersonalSkills = await codexPersonalTask.value
        codexSystemSkills = await codexSystemTask.value
        legacyCommands = await legacyTask.value

        for url in monitoredProjectURLs {
            let path = url.path
            projectSkills[path] = await Task.detached(priority: .userInitiated) {
                (try? FileSystemService().discoverProjectSkills(
                    projectPath: URL(fileURLWithPath: path))) ?? []
            }.value
            codexProjectSkills[path] = await Task.detached(priority: .userInitiated) {
                (try? FileSystemService().discoverCodexProjectSkills(
                    projectPath: URL(fileURLWithPath: path))) ?? []
            }.value
        }

        // Plugin skills
        let plugins = PluginService().discoverPlugins()
        installedPlugins = plugins
        for plugin in plugins {
            let p = plugin
            pluginSkills[p.id] = await Task.detached(priority: .userInitiated) {
                PluginService().discoverSkills(for: p)
            }.value
        }

    }

    // MARK: - CRUD

    @MainActor
    func createSkill(
        name: String,
        frontmatter: SkillFrontmatter,
        markdownContent: String,
        location: SkillLocation
    ) async throws {
        let dir = try await Task.detached(priority: .userInitiated) {
            try SkillCRUDService().createSkill(
                name: name,
                frontmatter: frontmatter,
                markdownContent: markdownContent,
                location: location
            )
        }.value
        await loadAllSkills()
        selectedSkill = allSkills.first { $0.directoryURL.path == dir.path }
    }

    @MainActor
    func updateSkill(
        _ skill: Skill,
        newFrontmatter: SkillFrontmatter,
        newMarkdownContent: String
    ) async throws {
        guard !skill.location.isReadOnly else { throw AppStateError.readOnlySkill }
        let dirPath = skill.directoryURL.path
        try await Task.detached(priority: .userInitiated) {
            try SkillCRUDService().updateSkill(
                skill,
                newFrontmatter: newFrontmatter,
                newMarkdownContent: newMarkdownContent
            )
        }.value
        await loadAllSkills()
        selectedSkill = allSkills.first { $0.directoryURL.path == dirPath }
    }

    @MainActor
    func deleteSkill(_ skill: Skill) async throws {
        guard !skill.location.isReadOnly else { throw AppStateError.readOnlySkill }
        // Clear selection before deleting to avoid showing a stale detail view
        if selectedSkill?.directoryURL.path == skill.directoryURL.path {
            selectedSkill = nil
        }
        try await Task.detached(priority: .userInitiated) {
            try SkillCRUDService().deleteSkill(skill)
        }.value
        await loadAllSkills()
    }

    // MARK: - Export

    @MainActor
    func exportSkill(_ skill: Skill) {
        let panel = NSSavePanel()
        panel.title = "Export Skill"
        panel.message = "Choose where to save \"\(skill.name).zip\""
        panel.canCreateDirectories = true
        panel.allowedContentTypes = [.zip]
        panel.nameFieldStringValue = "\(skill.name).zip"
        panel.prompt = "Export"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task {
            do {
                try await Task.detached(priority: .userInitiated) {
                    try SkillExportService().export(skill, to: url)
                }.value
                NSWorkspace.shared.activateFileViewerSelecting([url])
            } catch {
                await MainActor.run { self.lastError = error.localizedDescription }
            }
        }
    }

    // MARK: - Import

    /// Open a folder/ZIP picker and begin the two-phase import flow.
    @MainActor
    func triggerImport() {
        let panel = NSOpenPanel()
        panel.title = "Import Skill"
        panel.message = "Select a skill folder or ZIP archive"
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.zip, .folder]
        panel.prompt = "Import"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task { await startImport(from: url) }
    }

    /// Begin phase 1 (preview) for an archive at `url` — used by both the
    /// menu command and drag-and-drop.
    @MainActor
    func startImport(from url: URL) async {
        do {
            let package = try await Task.detached(priority: .userInitiated) {
                try SkillImportService().preview(from: url)
            }.value
            pendingImportPackage = package
            showImportSheet = true
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Phase 2 (commit), called from `ImportSkillView` after the user confirms.
    @MainActor
    func importSkill(_ package: SkillPackage, name: String, location: SkillLocation) async throws {
        defer { SkillImportService.cleanupIfTemporary(package) }
        let dir = try await Task.detached(priority: .userInitiated) {
            try SkillImportService().commit(package, name: name, location: location)
        }.value
        await loadAllSkills()
        selectedSkill = allSkills.first { $0.directoryURL.path == dir.path }
    }

    /// Fork a plugin skill to Personal skills.
    @MainActor
    func forkSkillToPersonal(_ skill: Skill) async throws {
        let name = skill.name
        let frontmatter = skill.frontmatter
        let content = skill.markdownContent
        let dir = try await Task.detached(priority: .userInitiated) {
            try SkillCRUDService().createSkill(
                name: name,
                frontmatter: frontmatter,
                markdownContent: content,
                location: .personal
            )
        }.value
        await loadAllSkills()
        selectedSkill = allSkills.first { $0.directoryURL.path == dir.path }
    }

    /// Toggle a skill's enabled state (renames SKILL.md ↔ SKILL.md.disabled).
    @MainActor
    func toggleSkillEnabled(_ skill: Skill) async throws {
        guard !skill.location.isReadOnly else { throw AppStateError.readOnlySkill }
        let dirPath = skill.directoryURL.path
        let newEnabled = !skill.isEnabled
        try await Task.detached(priority: .userInitiated) {
            try SkillCRUDService().setSkillEnabled(skill, enabled: newEnabled)
        }.value
        await loadAllSkills()
        selectedSkill = allSkills.first { $0.directoryURL.path == dirPath }
    }

    // MARK: - Projects

    @MainActor
    func addProject(_ url: URL) async {
        guard !monitoredProjectURLs.contains(url) else { return }
        monitoredProjectURLs.append(url)
        let path = url.path
        let skills = await Task.detached {
            (try? FileSystemService().discoverProjectSkills(projectPath: URL(fileURLWithPath: path))) ?? []
        }.value
        let codexSkills = await Task.detached {
            (try? FileSystemService().discoverCodexProjectSkills(projectPath: URL(fileURLWithPath: path))) ?? []
        }.value
        projectSkills[url.path] = skills
        codexProjectSkills[url.path] = codexSkills
        persistProjectPaths()
    }

    @MainActor func removeProject(_ url: URL) {
        monitoredProjectURLs.removeAll { $0 == url }
        projectSkills.removeValue(forKey: url.path)
        codexProjectSkills.removeValue(forKey: url.path)
        persistProjectPaths()
    }

    @MainActor
    func applySettingsAndReload() async {
        settingsRevision += 1
        await loadAllSkills()
    }

    // MARK: - Updates

    @MainActor
    func checkForUpdates(manual: Bool) async {
        if isCheckingUpdates { return }
        if !manual, !shouldRunAutomaticUpdateCheck() { return }

        isCheckingUpdates = true
        defer { isCheckingUpdates = false }

        let result = await updateService.checkForUpdates()
        lastUpdateCheckAt = Date()
        persistLastUpdateCheckAt()

        switch result {
        case .upToDate:
            updateStatusMessage = String(localized: "You're on the latest version.")
        case .updateAvailable(let release):
            latestReleaseInfo = release
            updateStatusMessage = String(localized: "Update available: \(release.version)")
            showUpdatePrompt = true
        case .noStableRelease:
            updateStatusMessage = String(localized: "No stable release found.")
        case .networkError(let message):
            updateStatusMessage = message
        }
    }

    @MainActor
    func performAutomaticUpdateCheckIfNeeded() async {
        await checkForUpdates(manual: false)
    }

    @MainActor
    func downloadAndOpenLatestUpdate() async {
        guard let release = latestReleaseInfo else { return }
        do {
            let localDMG = try await updateService.downloadLatestDMG(from: release)
            pendingDownloadURL = localDMG
            let opened = NSWorkspace.shared.open(localDMG)
            if opened {
                updateStatusMessage = String(localized: "Update package opened. Skill-MT will now quit so you can finish installation.")
                // Give Finder a brief moment to mount and foreground the DMG window before quitting.
                try? await Task.sleep(nanoseconds: 800_000_000)
                NSApp.terminate(nil)
            } else {
                updateStatusMessage = String(localized: "Failed to open update package.")
            }
        } catch {
            updateStatusMessage = error.localizedDescription
            lastError = error.localizedDescription
        }
    }

    @MainActor
    func openLatestReleasePage() {
        guard let url = latestReleaseInfo?.releaseURL else { return }
        NSWorkspace.shared.open(url)
    }

    private func shouldRunAutomaticUpdateCheck() -> Bool {
        guard let last = lastUpdateCheckAt else { return true }
        return Date().timeIntervalSince(last) >= 24 * 60 * 60
    }

    // MARK: - Persistence (project paths via UserDefaults)

    init(settings: AppSettings = .shared) {
        self.settings = settings
        let saved = UserDefaults.standard.stringArray(forKey: "monitoredProjectPaths") ?? []
        monitoredProjectURLs = saved.map { URL(fileURLWithPath: $0) }
        let providerRaw = UserDefaults.standard.string(forKey: "selectedProvider") ?? ""
        selectedProvider = SkillProvider(rawValue: providerRaw) ?? .claude
        if let ts = UserDefaults.standard.object(forKey: "lastUpdateCheckAt") as? TimeInterval {
            lastUpdateCheckAt = Date(timeIntervalSince1970: ts)
        }
    }

    private func persistProjectPaths() {
        UserDefaults.standard.set(
            monitoredProjectURLs.map(\.path),
            forKey: "monitoredProjectPaths"
        )
    }

    private func persistLastUpdateCheckAt() {
        UserDefaults.standard.set(lastUpdateCheckAt?.timeIntervalSince1970, forKey: "lastUpdateCheckAt")
    }
}
