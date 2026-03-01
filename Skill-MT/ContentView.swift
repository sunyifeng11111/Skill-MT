import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Bindable var appState: AppState
    @State private var fileWatcher = FileWatcher()
    @Environment(\.localization) private var localization

    var body: some View {
        NavigationSplitView {
            SkillListView(state: appState)
                .id(localization.language.rawValue)
        } detail: {
            if let skill = appState.selectedSkill {
                SkillDetailView(skill: skill, appState: appState)
            } else {
                EmptyStateView(
                    icon: "bookmark.square",
                    title: localization.string("Select a Skill"),
                    message: localization.string("Skills are reusable instructions for coding assistants. Select one from the list to view its details."),
                    learnMoreURL: URL(string: "https://agentskills.io")
                )
            }
        }
        .background {
            LinearGradient(
                stops: [
                    .init(color: Color.accentColor.opacity(0.07), location: 0),
                    .init(color: Color.accentColor.opacity(0.02), location: 0.6),
                    .init(color: Color(NSColor.windowBackgroundColor), location: 1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
        .toolbarBackground(.hidden, for: .windowToolbar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("Provider", selection: $appState.selectedProvider) {
                    ForEach(SkillProvider.allCases) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    appState.showCreateSheet = true
                } label: {
                    Label("New Skill", systemImage: "plus")
                }
                .help("Create a new skill")
            }
            ToolbarItem(placement: .navigation) {
                Button {
                    appState.showSettingsSheet = true
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
                .help("Settings")
            }
        }
        .frame(minWidth: 700, minHeight: 500)
        .task {
            await appState.loadAllSkills()
            startWatching()
            await appState.performAutomaticUpdateCheckIfNeeded()
        }
        .onChange(of: appState.settingsRevision) { _, _ in
            startWatching()
        }
        .onChange(of: appState.monitoredProjectURLs) { _, _ in
            startWatching()
        }
        .onReceive(NotificationCenter.default.publisher(
            for: NSApplication.willTerminateNotification)
        ) { _ in
            fileWatcher.stopAll()
        }
        .sheet(isPresented: $appState.showCreateSheet) {
            CreateSkillView(appState: appState)
        }
        .sheet(isPresented: $appState.showSettingsSheet) {
            SettingsView(appState: appState)
        }
        .sheet(isPresented: $appState.showImportSheet, onDismiss: {
            if let package = appState.pendingImportPackage {
                SkillImportService.cleanupIfTemporary(package)
            }
            appState.pendingImportPackage = nil
        }) {
            if let package = appState.pendingImportPackage {
                ImportSkillView(package: package, appState: appState)
            }
        }
        .alert("Error", isPresented: Binding(
            get: { appState.lastError != nil },
            set: { if !$0 { appState.lastError = nil } }
        )) {
            Button("OK") { appState.lastError = nil }
        } message: {
            Text(appState.lastError ?? "")
        }
        .alert(String(localized: "Update Available"), isPresented: $appState.showUpdatePrompt) {
            Button(String(localized: "Download Update")) {
                Task { await appState.downloadAndOpenLatestUpdate() }
            }
            Button(String(localized: "View Release Notes")) {
                appState.openLatestReleasePage()
            }
            Button(String(localized: "Later"), role: .cancel) { }
        } message: {
            Text(String(localized: "A newer version is available."))
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            guard let provider = providers.first(where: {
                $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
            }) else { return false }
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                guard let data = item as? Data,
                      let url = NSURL(absoluteURLWithDataRepresentation: data, relativeTo: nil) as URL?
                else { return }
                let isZip = url.pathExtension.lowercased() == "zip"
                var isDirectory: ObjCBool = false
                let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
                guard exists, isZip || (isDirectory.boolValue &&
                      FileManager.default.fileExists(atPath: url.appendingPathComponent("SKILL.md").path))
                else { return }
                DispatchQueue.main.async {
                    Task { await appState.startImport(from: url) }
                }
            }
            return true
        }
    }

    // MARK: - File Watcher

    private func startWatching() {
        var watchURLs: [URL] = []
        let personal = FileSystemPaths.personalSkillsURL(settings: appState.settings)
        if FileManager.default.fileExists(atPath: personal.path) {
            watchURLs.append(personal)
        }
        let codexPersonal = FileSystemPaths.codexSkillsURL(settings: appState.settings)
        if FileManager.default.fileExists(atPath: codexPersonal.path) {
            watchURLs.append(codexPersonal)
        }
        let codexSystem = FileSystemPaths.codexSystemSkillsURL(settings: appState.settings)
        if FileManager.default.fileExists(atPath: codexSystem.path) {
            watchURLs.append(codexSystem)
        }
        for url in appState.monitoredProjectURLs {
            let claudeSkillsURL = url.appendingPathComponent(".claude/skills")
            if FileManager.default.fileExists(atPath: claudeSkillsURL.path) {
                watchURLs.append(claudeSkillsURL)
            }
            let codexProjectSkillsURL = FileSystemPaths.codexProjectSkillsURL(projectPath: url)
            if FileManager.default.fileExists(atPath: codexProjectSkillsURL.path) {
                watchURLs.append(codexProjectSkillsURL)
            }
        }
        fileWatcher.watch(urls: watchURLs)
        fileWatcher.onChange = {
            Task { await appState.loadAllSkills() }
        }
    }
}
