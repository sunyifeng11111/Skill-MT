import SwiftUI

struct SkillDetailView: View {
    let skill: Skill
    @Bindable var appState: AppState
    @Environment(\.localization) private var localization
    @State private var showOpenSupportingFileAlert: Bool = false
    @State private var showDiscardAlert: Bool = false
    @State private var pendingSupportingFileURL: URL?
    @State private var pendingSupportingFileRelativePath: String = ""
    @State private var expandedSupportingDirectories: Set<String> = []
    @State private var isEditingInline: Bool = false
    @State private var description: String = ""
    @State private var argumentHint: String = ""
    @State private var userInvocable: Bool = true
    @State private var disableModelInvocation: Bool = false
    @State private var allowedTools: String = ""
    @State private var model: String = ""
    @State private var context: String = ""
    @State private var agent: String = ""
    @State private var markdownContent: String = ""
    @State private var initialDescription: String = ""
    @State private var initialArgumentHint: String = ""
    @State private var initialUserInvocable: Bool = true
    @State private var initialDisableModelInvocation: Bool = false
    @State private var initialAllowedTools: String = ""
    @State private var initialModel: String = ""
    @State private var initialContext: String = ""
    @State private var initialAgent: String = ""
    @State private var initialMarkdownContent: String = ""
    @State private var isSaving: Bool = false
    @State private var saveError: String?
    @State private var saveStatusMessage: String?

    var body: some View {
        Group {
            if isEditingInline {
                VStack(alignment: .leading, spacing: 12) {
                    if isPluginSkill {
                        pluginReadOnlyBanner
                    } else if isCodexSystemSkill {
                        codexSystemReadOnlyBanner
                    }
                    headerSection
                    inlineEditorSection
                        .frame(maxHeight: .infinity, alignment: .top)
                }
                .padding(16)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if isPluginSkill {
                            pluginReadOnlyBanner
                        } else if isCodexSystemSkill {
                            codexSystemReadOnlyBanner
                        }
                        headerSection
                        frontmatterSection
                        contentSection
                        if !skill.supportingFiles.isEmpty {
                            supportingFilesSection
                        }
                    }
                    .padding(16)
                }
            }
        }
        .background {
            // Subtle accent gradient gives glass cards an interesting surface to
            // reflect, and replaces the flat system gray with a warmer base.
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
        .navigationTitle(skill.displayName)
        .toolbar {
            detailToolbar
        }
        .alert(localization.string("Open file?"), isPresented: $showOpenSupportingFileAlert) {
            Button(localization.string("Open")) {
                if let url = pendingSupportingFileURL {
                    NSWorkspace.shared.open(url)
                }
                clearPendingSupportingFile()
            }
            Button(localization.string("Reveal in Finder")) {
                if let url = pendingSupportingFileURL {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
                clearPendingSupportingFile()
            }
            Button(localization.string("Cancel"), role: .cancel) {
                clearPendingSupportingFile()
            }
        } message: {
            Text(
                String(
                    format: localization.string("Do you want to open \"%@\"?"),
                    pendingSupportingFileRelativePath
                )
            )
        }
        .alert(localization.string("Discard unsaved changes?"), isPresented: $showDiscardAlert) {
            Button(localization.string("Discard Changes"), role: .destructive) {
                exitInlineEditing(discardChanges: true)
            }
            Button(localization.string("Continue Editing"), role: .cancel) {}
        } message: {
            Text(localization.string("You have unsaved changes. Discard them and leave edit mode?"))
        }
        .onAppear {
            resetEditorState(from: skill)
        }
        .onChange(of: skill.directoryURL.path) { _, _ in
            resetEditorState(from: skill)
        }
        .onChange(of: skill.lastModified) { _, _ in
            if !isEditingInline {
                resetEditorState(from: skill)
            }
        }
    }

    // MARK: - Plugin Banner

    private var pluginReadOnlyBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "puzzlepiece.extension")
                .foregroundStyle(.purple)
            VStack(alignment: .leading, spacing: 2) {
                Text(localization.string("Plugin skill — read only"))
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(localization.string("Fork to Personal Skills to edit or customize."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                Task {
                    try? await appState.forkSkillToPersonal(skill)
                }
            } label: {
                Label(localization.string("Fork to Personal"), systemImage: "arrow.turn.down.left")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(12)
        .background(Color.purple.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.purple.opacity(0.2), lineWidth: 0.5)
        }
    }

    private var codexSystemReadOnlyBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "gearshape")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(localization.string("System skill — read only"))
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(localization.string("Built-in Codex skills cannot be edited or deleted."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.orange.opacity(0.2), lineWidth: 0.5)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: skill.isLegacyCommand ? "terminal" : "bookmark.square.fill")
                    .font(.title2)
                    .foregroundStyle(.tint)
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 3) {
                    Text(skill.displayName)
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text(skill.skillFileURL.path(percentEncoded: false))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            HStack(spacing: 6) {
                locationBadge
                if isPluginSkill {
                    badge(localization.string("Plugin"), color: .purple, icon: "puzzlepiece.extension")
                }
                if !skill.isEnabled {
                    badge(localization.string("Disabled"), color: .red, icon: "pause.circle.fill")
                }
                if skill.frontmatter.disableModelInvocation {
                    badge(localization.string("Auto-off"), color: .orange, icon: "bolt.slash")
                }
                if !skill.frontmatter.userInvocable {
                    badge(localization.string("Hidden"), color: .secondary, icon: "eye.slash")
                }
                if skill.frontmatter.context == "fork" {
                    badge(localization.string("Fork"), color: .purple, icon: "arrow.triangle.branch")
                }
            }

            Text("\(localization.string("Modified")) \(skill.lastModified.formatted(.relative(presentation: .named)))")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardPanel()
    }

    // MARK: - Frontmatter

    private var frontmatterSection: some View {
        FrontmatterView(frontmatter: skill.frontmatter)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardPanel()
    }

    // MARK: - Content

    private var contentSection: some View {
        MarkdownPreviewView(content: skill.markdownContent)
            .frame(maxWidth: .infinity, minHeight: 200, alignment: .topLeading)
            .cardPanel()
    }

    private var inlineEditorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let saveStatusMessage {
                Text(saveStatusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let saveError {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text(saveError)
                        .font(.caption)
                        .foregroundStyle(.red)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            }

            HSplitView {
                ScrollView {
                    SkillEditorFieldsView(
                        hooksRaw: skill.frontmatter.hooksRaw,
                        description: $description,
                        argumentHint: $argumentHint,
                        userInvocable: $userInvocable,
                        disableModelInvocation: $disableModelInvocation,
                        allowedTools: $allowedTools,
                        model: $model,
                        context: $context,
                        agent: $agent
                    )
                    .padding(.vertical, 8)
                }
                .frame(minWidth: 380)
                .layoutPriority(1)

                SkillEditorContentView(markdownContent: $markdownContent)
                    .padding(.vertical, 8)
                    .frame(minWidth: 520, maxWidth: .infinity, minHeight: 520, alignment: .topLeading)
                    .layoutPriority(2)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .cardPanel()
    }

    // MARK: - Supporting Files

    private var supportingFilesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(localization.string("Supporting Files"))
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 8)

            ForEach(supportingFileTree) { node in
                supportingFileBranch(node, level: 0)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardPanel()
    }

    private func supportingFileBranch(_ node: SupportingFileTreeNode, level: Int) -> AnyView {
        AnyView(
            VStack(alignment: .leading, spacing: 0) {
                supportingFileNodeRow(node, level: level)
                if node.isDirectory,
                   expandedSupportingDirectories.contains(node.id),
                   let children = node.children {
                    ForEach(children) { child in
                        supportingFileBranch(child, level: level + 1)
                    }
                }
            }
        )
    }

    private func supportingFileNodeRow(_ node: SupportingFileTreeNode, level: Int) -> some View {
        HStack(spacing: 10) {
            if node.isDirectory {
                Image(systemName: expandedSupportingDirectories.contains(node.id) ? "chevron.down" : "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(width: 10)
            } else {
                Color.clear.frame(width: 10, height: 1)
            }
            Image(systemName: node.isDirectory ? "folder" : "doc.text")
                .foregroundStyle(.secondary)
                .frame(width: 16)
            Text(node.name)
                .font(.system(.caption, design: .monospaced))
            Spacer()
            if !node.isDirectory {
                Text(ByteCountFormatter.string(fromByteCount: node.fileSize, countStyle: .file))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 6)
        .padding(.leading, CGFloat(level) * 22)
        .contentShape(Rectangle())
        .onTapGesture {
            if node.isDirectory {
                withAnimation(.easeInOut(duration: 0.15)) {
                    if expandedSupportingDirectories.contains(node.id) {
                        expandedSupportingDirectories.remove(node.id)
                    } else {
                        expandedSupportingDirectories.insert(node.id)
                    }
                }
            } else {
                pendingSupportingFileURL = node.fileURL
                pendingSupportingFileRelativePath = node.relativePath
                showOpenSupportingFileAlert = true
            }
        }
    }

    private var supportingFileTree: [SupportingFileTreeNode] {
        buildSupportingFileTree(from: skill.supportingFiles)
    }

    private func buildSupportingFileTree(from files: [SkillFile]) -> [SupportingFileTreeNode] {
        final class MutableNode {
            let name: String
            var relativePath: String
            var fileURL: URL
            var isDirectory: Bool
            var fileSize: Int64
            var children: [String: MutableNode]

            init(
                name: String,
                relativePath: String,
                fileURL: URL,
                isDirectory: Bool,
                fileSize: Int64 = 0
            ) {
                self.name = name
                self.relativePath = relativePath
                self.fileURL = fileURL
                self.isDirectory = isDirectory
                self.fileSize = fileSize
                self.children = [:]
            }
        }

        let root = MutableNode(
            name: "",
            relativePath: "",
            fileURL: skill.directoryURL,
            isDirectory: true
        )

        for file in files {
            let components = file.relativePath.split(separator: "/").map(String.init)
            guard !components.isEmpty else { continue }

            var current = root
            var pathParts: [String] = []

            for (index, component) in components.enumerated() {
                pathParts.append(component)
                let fullPath = pathParts.joined(separator: "/")
                let isLeaf = index == components.count - 1
                let leafIsDirectory = isLeaf ? file.isDirectory : true
                let nodeURL = skill.directoryURL.appendingPathComponent(fullPath)

                let node: MutableNode
                if let existing = current.children[component] {
                    node = existing
                } else {
                    let created = MutableNode(
                        name: component,
                        relativePath: fullPath,
                        fileURL: nodeURL,
                        isDirectory: leafIsDirectory,
                        fileSize: isLeaf ? file.fileSize : 0
                    )
                    current.children[component] = created
                    node = created
                }

                if isLeaf {
                    node.relativePath = file.relativePath
                    node.fileURL = file.fileURL
                    node.isDirectory = file.isDirectory
                    node.fileSize = file.fileSize
                }

                current = node
            }
        }

        func sortNodes(_ lhs: MutableNode, _ rhs: MutableNode) -> Bool {
            if lhs.isDirectory != rhs.isDirectory {
                return lhs.isDirectory && !rhs.isDirectory
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }

        func toTreeNode(_ node: MutableNode) -> SupportingFileTreeNode {
            let sortedChildren = node.children.values.sorted(by: sortNodes)
            let childNodes = sortedChildren.map(toTreeNode)
            return SupportingFileTreeNode(
                name: node.name,
                relativePath: node.relativePath,
                fileURL: node.fileURL,
                isDirectory: node.isDirectory,
                fileSize: node.fileSize,
                children: childNodes.isEmpty ? nil : childNodes
            )
        }

        return root.children.values
            .sorted(by: sortNodes)
            .map(toTreeNode)
    }

    private func clearPendingSupportingFile() {
        showOpenSupportingFileAlert = false
        pendingSupportingFileURL = nil
        pendingSupportingFileRelativePath = ""
    }

    // MARK: - Badges

    private var locationBadge: some View {
        switch skill.location {
        case .personal:
            return badge(localization.string("Personal"), color: .accentColor, icon: "person.crop.circle")
        case .codexPersonal:
            return badge(localization.string("Personal"), color: .accentColor, icon: "person.crop.circle")
        case .codexSystem:
            return badge(localization.string("System Skill"), color: .orange, icon: "gearshape")
        case .legacyCommand:
            return badge(localization.string("Legacy Command"), color: .orange, icon: "terminal")
        case .project(let path):
            return badge(URL(fileURLWithPath: path).lastPathComponent, color: .accentColor, icon: "folder")
        case .codexProject(let path):
            return badge(URL(fileURLWithPath: path).lastPathComponent, color: .accentColor, icon: "folder")
        case .plugin(_, let name, _):
            return badge(name, color: .purple, icon: "puzzlepiece.extension")
        }
    }

    private func badge(_ label: String, color: Color, icon: String) -> some View {
        Label(label, systemImage: icon)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.12), in: Capsule())
            .foregroundStyle(color)
    }

    private var isPluginSkill: Bool {
        if case .plugin = skill.location { return true }
        return false
    }

    private var isCodexSystemSkill: Bool {
        if case .codexSystem = skill.location { return true }
        return false
    }

    private var moveTargets: [SkillLocation] {
        appState.availableMoveTargets(for: skill)
    }

    // MARK: - Toolbar

    private var detailToolbar: some ToolbarContent {
        ToolbarItemGroup {
            Button {
                Task { try? await appState.toggleSkillEnabled(skill) }
            } label: {
                Image(systemName: skill.isEnabled ? "pause.circle" : "play.circle")
            }
            .accessibilityLabel(skill.isEnabled ? localization.string("Disable") : localization.string("Enable"))
            .help(skill.isEnabled ? localization.string("Disable this skill") : localization.string("Enable this skill"))
            .disabled(skill.location.isReadOnly)

            Menu {
                if moveTargets.isEmpty {
                    Text(localization.string("No available move target"))
                } else {
                    ForEach(moveTargets, id: \.self) { target in
                        Button {
                            Task { try? await appState.moveSkill(skill, to: target) }
                        } label: {
                            Text(moveTargetLabel(target))
                        }
                    }
                }
            } label: {
                Label(localization.string("Move To"), systemImage: "arrow.left.arrow.right.circle")
            }
            .disabled(skill.location.isReadOnly || moveTargets.isEmpty)
            .help(localization.string("Move this skill to another location"))

            Button {
                NSWorkspace.shared.activateFileViewerSelecting([skill.directoryURL])
            } label: {
                Label(localization.string("Show in Finder"), systemImage: "folder")
            }
            .help(localization.string("Reveal in Finder"))

            Button {
                appState.exportSkill(skill)
            } label: {
                Label(localization.string("Export"), systemImage: "square.and.arrow.up")
            }
            .disabled(skill.isLegacyCommand || isPluginSkill)
            .help(
                isPluginSkill
                    ? localization.string("Plugin skills cannot be exported")
                    : skill.isLegacyCommand
                        ? localization.string("Legacy commands cannot be exported")
                        : localization.string("Export this skill as a ZIP archive")
            )

            Button {
                if isEditingInline {
                    attemptExitInlineEditing()
                } else {
                    startInlineEditing()
                }
            } label: {
                Label(
                    isEditingInline ? localization.string("Done") : localization.string("Edit"),
                    systemImage: isEditingInline ? "checkmark.circle" : "pencil"
                )
            }
            .disabled(skill.isLegacyCommand || skill.location.isReadOnly)
            .help(
                isPluginSkill
                    ? localization.string("Plugin skills are read-only")
                    : isCodexSystemSkill
                        ? localization.string("System skills are read-only")
                        : skill.isLegacyCommand
                            ? localization.string("Legacy commands cannot be edited here")
                            : isEditingInline
                                ? localization.string("Leave edit mode")
                                : localization.string("Edit this skill")
            )

            if isEditingInline {
                Button {
                    Task { await saveInlineChanges() }
                } label: {
                    if isSaving {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text(localization.string("Save"))
                    }
                }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(!hasChanges || isSaving)
                .help(localization.string("Save changes"))
            }
        }
    }

    private func moveTargetLabel(_ location: SkillLocation) -> String {
        switch location {
        case .personal, .codexPersonal:
            return localization.string("Move to Global Skills")
        case .project(let path), .codexProject(let path):
            return String(
                format: localization.string("Move to Project: %@"),
                URL(fileURLWithPath: path).lastPathComponent
            )
        default:
            return location.displayName
        }
    }

    private var hasChanges: Bool {
        description != initialDescription ||
        argumentHint != initialArgumentHint ||
        userInvocable != initialUserInvocable ||
        disableModelInvocation != initialDisableModelInvocation ||
        allowedTools != initialAllowedTools ||
        model != initialModel ||
        context != initialContext ||
        agent != initialAgent ||
        markdownContent != initialMarkdownContent
    }

    private func resetEditorState(from skill: Skill) {
        let frontmatter = skill.frontmatter
        description = frontmatter.description ?? ""
        argumentHint = frontmatter.argumentHint ?? ""
        userInvocable = frontmatter.userInvocable
        disableModelInvocation = frontmatter.disableModelInvocation
        allowedTools = frontmatter.allowedTools ?? ""
        model = frontmatter.model ?? ""
        context = frontmatter.context ?? ""
        agent = frontmatter.agent ?? ""
        markdownContent = skill.markdownContent

        initialDescription = description
        initialArgumentHint = argumentHint
        initialUserInvocable = userInvocable
        initialDisableModelInvocation = disableModelInvocation
        initialAllowedTools = allowedTools
        initialModel = model
        initialContext = context
        initialAgent = agent
        initialMarkdownContent = markdownContent

        saveStatusMessage = nil
        saveError = nil
    }

    private func startInlineEditing() {
        resetEditorState(from: skill)
        isEditingInline = true
    }

    private func attemptExitInlineEditing() {
        if hasChanges {
            showDiscardAlert = true
        } else {
            exitInlineEditing(discardChanges: false)
        }
    }

    private func exitInlineEditing(discardChanges: Bool) {
        if discardChanges {
            resetEditorState(from: skill)
        }
        isEditingInline = false
        saveStatusMessage = nil
        saveError = nil
    }

    @MainActor
    private func saveInlineChanges() async {
        guard hasChanges else { return }
        isSaving = true
        saveError = nil
        saveStatusMessage = localization.string("Saving...")

        let newFrontmatter = SkillFrontmatter(
            name: skill.frontmatter.name,
            description: description.isEmpty ? nil : description,
            argumentHint: argumentHint.isEmpty ? nil : argumentHint,
            disableModelInvocation: disableModelInvocation,
            userInvocable: userInvocable,
            allowedTools: allowedTools.isEmpty ? nil : allowedTools,
            model: model.isEmpty ? nil : model,
            context: context.isEmpty ? nil : context,
            agent: agent.isEmpty ? nil : agent,
            hooksRaw: skill.frontmatter.hooksRaw
        )

        do {
            try await appState.updateSkill(
                skill,
                newFrontmatter: newFrontmatter,
                newMarkdownContent: markdownContent
            )
            initialDescription = description
            initialArgumentHint = argumentHint
            initialUserInvocable = userInvocable
            initialDisableModelInvocation = disableModelInvocation
            initialAllowedTools = allowedTools
            initialModel = model
            initialContext = context
            initialAgent = agent
            initialMarkdownContent = markdownContent
            saveStatusMessage = localization.string("Saved")
        } catch {
            saveError = error.localizedDescription
            saveStatusMessage = nil
        }

        isSaving = false
    }
}

private struct SupportingFileTreeNode: Identifiable, Hashable {
    var id: String { relativePath }
    let name: String
    let relativePath: String
    let fileURL: URL
    let isDirectory: Bool
    let fileSize: Int64
    let children: [SupportingFileTreeNode]?
}

// MARK: - Card Panel Modifier

private struct CardPanel: ViewModifier {
    func body(content: Content) -> some View {
        content
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.primary.opacity(0.06))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.primary.opacity(0.07), lineWidth: 0.5)
                    }
            }
    }
}

extension View {
    func cardPanel() -> some View {
        modifier(CardPanel())
    }
}
