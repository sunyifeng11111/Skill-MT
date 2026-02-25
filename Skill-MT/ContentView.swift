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
                    .id(skill.id)
            } else {
                EmptyStateView(
                    icon: "bookmark.square",
                    title: String(localized: "Select a Skill"),
                    message: String(localized: "Skills are reusable instructions that Claude Code can invoke. Select one from the list to view its details."),
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
            SettingsView()
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
        let personal = FileSystemPaths.personalSkillsURL
        if FileManager.default.fileExists(atPath: personal.path) {
            watchURLs.append(personal)
        }
        for url in appState.monitoredProjectURLs {
            let skillsURL = url.appendingPathComponent(".claude/skills")
            if FileManager.default.fileExists(atPath: skillsURL.path) {
                watchURLs.append(skillsURL)
            }
        }
        fileWatcher.watch(urls: watchURLs)
        fileWatcher.onChange = {
            Task { await appState.loadAllSkills() }
        }
    }
}
