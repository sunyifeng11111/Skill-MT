import SwiftUI

struct SkillListView: View {
    @Bindable var state: AppState
    @State private var selectedSource: SkillSource = .personal
    @State private var selectedIDs: Set<Skill.ID> = []
    @Environment(\.localization) private var localization

    private var currentSkills: [Skill] {
        switch state.selectedProvider {
        case .claude:
            switch selectedSource {
            case .personal:
                return state.filteredPersonalSkills
            case .project(let url):
                return state.filteredProjectSkills(for: url.path)
            case .legacyCommands:
                return state.filteredLegacyCommands
            case .plugin(let id):
                return state.filteredPluginSkills(for: id)
            case .codexSystem:
                return []
            }
        case .codex:
            switch selectedSource {
            case .personal:
                return state.filteredCodexPersonalSkills
            case .codexSystem:
                return state.filteredCodexSystemSkills
            case .project, .legacyCommands, .plugin:
                return []
            }
        }
    }

    private var selectedSkills: [Skill] {
        currentSkills.filter { selectedIDs.contains($0.id) }
    }

    var body: some View {
        VStack(spacing: 0) {
            sourceHeader

            Divider()
                .opacity(0.4)

            SkillFilterBar(
                searchText: $state.searchText,
                scopeLabel: selectedSource.displayName(provider: state.selectedProvider)
            )

            if !selectedIDs.isEmpty {
                batchToolbar
                Divider().opacity(0.4)
            }

            if currentSkills.isEmpty {
                emptyState
            } else {
                skillList
            }

            Divider()

            Button {
                state.triggerImport()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.subheadline)
                    Text("Import Skill")
                        .font(.subheadline)
                }
                .foregroundStyle(Color.accentColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
        }
        .onChange(of: state.selectedProvider) { _, _ in
            selectedSource = .personal
            selectedIDs = []
            state.selectedSkill = nil
        }
        .alert(
            "Delete \"\(state.skillToDelete?.displayName ?? "")\"?",
            isPresented: Binding(
                get: { state.skillToDelete != nil },
                set: { if !$0 { state.skillToDelete = nil } }
            ),
            presenting: state.skillToDelete
        ) { skill in
            Button("Delete", role: .destructive) {
                Task { try? await state.deleteSkill(skill) }
            }
            Button("Cancel", role: .cancel) {
                state.skillToDelete = nil
            }
        } message: { skill in
            Text("This will permanently remove the skill directory. This action cannot be undone.")
        }
        .background {
            LinearGradient(
                stops: [
                    .init(color: Color.accentColor.opacity(0.05), location: 0),
                    .init(color: Color.accentColor.opacity(0.01), location: 0.5),
                    .init(color: Color(NSColor.windowBackgroundColor), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }

    // MARK: - Source Header

    private var sourceHeader: some View {
        Menu {
            Button {
                selectedSource = .personal
            } label: {
                Label("Personal Skills", systemImage: "person.crop.circle")
            }

            if state.selectedProvider == .claude {
                if !state.monitoredProjectURLs.isEmpty {
                    Divider()
                    ForEach(state.monitoredProjectURLs, id: \.path) { url in
                        Menu {
                            Button {
                                selectedSource = .project(url: url)
                            } label: {
                                Label("Switch to \(url.lastPathComponent)", systemImage: "arrow.right.circle")
                            }
                            Divider()
                            Button(role: .destructive) {
                                if case .project(let sel) = selectedSource, sel == url {
                                    selectedSource = .personal
                                }
                                state.removeProject(url)
                            } label: {
                                Label("Remove Project", systemImage: "minus.circle")
                            }
                        } label: {
                            Label(url.lastPathComponent, systemImage: "folder")
                        }
                    }
                }

                if !state.legacyCommands.isEmpty {
                    Divider()
                    Button {
                        selectedSource = .legacyCommands
                    } label: {
                        Label("Legacy Commands", systemImage: "terminal")
                    }
                }

                if !state.installedPlugins.isEmpty {
                    Divider()
                    ForEach(state.installedPlugins, id: \.id) { plugin in
                        Button {
                            selectedSource = .plugin(id: plugin.id)
                        } label: {
                            Label(plugin.name, systemImage: "puzzlepiece.extension")
                        }
                    }
                }

                Divider()

                Button {
                    addProject()
                } label: {
                    Label(localization.string("Add Project…"), systemImage: "folder.badge.plus")
                }
            } else {
                Divider()
                Button {
                    selectedSource = .codexSystem
                } label: {
                    Label("System Skills", systemImage: "gearshape")
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: selectedSource.icon)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 18)
                Text(selectedSource.displayName(provider: state.selectedProvider))
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                Image(systemName: "chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Batch Toolbar

    private var mutableSelectedSkills: [Skill] {
        selectedSkills.filter { !$0.location.isReadOnly }
    }

    private var batchToolbar: some View {
        HStack(spacing: 8) {
            Text("\(selectedIDs.count) selected")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                Task {
                    for skill in mutableSelectedSkills where skill.isEnabled {
                        try? await state.toggleSkillEnabled(skill)
                    }
                    selectedIDs = []
                }
            } label: {
                Label("Disable", systemImage: "pause.circle")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(mutableSelectedSkills.isEmpty || mutableSelectedSkills.allSatisfy { !$0.isEnabled })

            Button {
                Task {
                    for skill in mutableSelectedSkills where !skill.isEnabled {
                        try? await state.toggleSkillEnabled(skill)
                    }
                    selectedIDs = []
                }
            } label: {
                Label("Enable", systemImage: "play.circle")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(mutableSelectedSkills.isEmpty || mutableSelectedSkills.allSatisfy { $0.isEnabled })

            Button {
                for skill in selectedSkills {
                    state.exportSkill(skill)
                }
                selectedIDs = []
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(selectedSkills.allSatisfy { $0.isLegacyCommand || $0.location.isPlugin })

            Button {
                selectedIDs = []
            } label: {
                Image(systemName: "xmark")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    // MARK: - Skill List

    private var skillList: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                ForEach(currentSkills) { skill in
                    HStack(spacing: 6) {
                        if !selectedIDs.isEmpty {
                            Image(systemName: selectedIDs.contains(skill.id) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selectedIDs.contains(skill.id) ? Color.accentColor : .secondary)
                                .font(.system(size: 16))
                                .onTapGesture {
                                    if selectedIDs.contains(skill.id) {
                                        selectedIDs.remove(skill.id)
                                    } else {
                                        selectedIDs.insert(skill.id)
                                    }
                                }
                        }
                        SkillRowView(skill: skill, isSelected: state.selectedSkill?.id == skill.id)
                            .contentShape(RoundedRectangle(cornerRadius: 10))
                            .onTapGesture {
                                if NSEvent.modifierFlags.contains(.command) {
                                    if selectedIDs.contains(skill.id) {
                                        selectedIDs.remove(skill.id)
                                    } else {
                                        selectedIDs.insert(skill.id)
                                    }
                                } else {
                                    state.selectedSkill = skill
                                    selectedIDs = []
                                }
                            }
                            .contextMenu { rowContextMenu(for: skill) }
                    }
                    .padding(.leading, selectedIDs.isEmpty ? 0 : 4)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        Group {
            if state.searchText.isEmpty {
                EmptyStateView(
                    icon: "bookmark.slash",
                    title: String(localized: "No Skills Yet"),
                    message: String(localized: "Skills are reusable instructions for coding assistants. Create your first skill with the + button above."),
                    action: { state.showCreateSheet = true },
                    actionLabel: String(localized: "Create Skill"),
                    learnMoreURL: URL(string: "https://agentskills.io")
                )
            } else {
                EmptyStateView(
                    icon: "magnifyingglass",
                    title: String(localized: "No Results"),
                    message: String(localized: "No skills match \"\(state.searchText)\"."),
                    action: { state.searchText = "" },
                    actionLabel: String(localized: "Clear Search")
                )
            }
        }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func rowContextMenu(for skill: Skill) -> some View {
        Button {
            NSWorkspace.shared.activateFileViewerSelecting([skill.directoryURL])
        } label: {
            Label("Show in Finder", systemImage: "folder")
        }
        Divider()
        Button {
            Task { try? await state.toggleSkillEnabled(skill) }
        } label: {
            Label(skill.isEnabled ? "Disable" : "Enable",
                  systemImage: skill.isEnabled ? "pause.circle" : "play.circle")
        }
        .disabled(skill.location.isReadOnly)
        Divider()
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(skill.skillFileURL.path, forType: .string)
        } label: {
            Label("Copy Path", systemImage: "doc.on.clipboard")
        }
        Button {
            state.exportSkill(skill)
        } label: {
            Label("Export…", systemImage: "square.and.arrow.up")
        }
        .disabled(skill.isLegacyCommand || skill.location.isPlugin)
        Divider()
        Button(role: .destructive) {
            state.skillToDelete = skill
        } label: {
            Label("Delete…", systemImage: "trash")
        }
        .disabled(skill.location.isReadOnly)
    }

    // MARK: - Add Project

    private func addProject() {
        let panel = NSOpenPanel()
        panel.title = "Select Project Root"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Add Project"
        if panel.runModal() == .OK, let url = panel.url {
            Task { await state.addProject(url) }
        }
    }
}

// MARK: - Skill Source

enum SkillSource: Hashable {
    case personal
    case project(url: URL)
    case legacyCommands
    case plugin(id: String)
    case codexSystem

    func displayName(provider _: SkillProvider) -> String {
        switch self {
        case .personal:
            return String(localized: "Personal Skills")
        case .project(let u):
            return u.lastPathComponent
        case .legacyCommands:
            return String(localized: "Legacy Commands")
        case .plugin(let id):
            return id.components(separatedBy: "@").first ?? id
        case .codexSystem:
            return String(localized: "System Skills")
        }
    }

    var icon: String {
        switch self {
        case .personal:       return "person.crop.circle"
        case .project:        return "folder"
        case .legacyCommands: return "terminal"
        case .plugin:         return "puzzlepiece.extension"
        case .codexSystem:    return "gearshape"
        }
    }
}
