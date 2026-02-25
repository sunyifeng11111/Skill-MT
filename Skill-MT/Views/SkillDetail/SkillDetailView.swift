import SwiftUI

struct SkillDetailView: View {
    let skill: Skill
    @Bindable var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if isPluginSkill {
                    pluginReadOnlyBanner
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
        .sheet(item: $appState.skillToEdit) { skillToEdit in
            EditSkillView(skill: skillToEdit, appState: appState)
        }
    }

    // MARK: - Plugin Banner

    private var pluginReadOnlyBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "puzzlepiece.extension")
                .foregroundStyle(.purple)
            VStack(alignment: .leading, spacing: 2) {
                Text("Plugin skill — read only")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("Fork to Personal Skills to edit or customize.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                Task {
                    try? await appState.forkSkillToPersonal(skill)
                }
            } label: {
                Label("Fork to Personal", systemImage: "arrow.turn.down.left")
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
                    badge(String(localized: "Plugin"), color: .purple, icon: "puzzlepiece.extension")
                }
                if !skill.isEnabled {
                    badge(String(localized: "Disabled"), color: .red, icon: "pause.circle.fill")
                }
                if skill.frontmatter.disableModelInvocation {
                    badge(String(localized: "Auto-off"), color: .orange, icon: "bolt.slash")
                }
                if !skill.frontmatter.userInvocable {
                    badge(String(localized: "Hidden"), color: .secondary, icon: "eye.slash")
                }
                if skill.frontmatter.context == "fork" {
                    badge(String(localized: "Fork"), color: .purple, icon: "arrow.triangle.branch")
                }
            }

            Text("Modified \(skill.lastModified.formatted(.relative(presentation: .named)))")
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

    // MARK: - Supporting Files

    private var supportingFilesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Supporting Files")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 8)

            ForEach(skill.supportingFiles) { file in
                HStack(spacing: 10) {
                    Image(systemName: file.isDirectory ? "folder" : "doc.text")
                        .foregroundStyle(.secondary)
                        .frame(width: 16)
                    Text(file.relativePath)
                        .font(.system(.caption, design: .monospaced))
                    Spacer()
                    if !file.isDirectory {
                        Text(ByteCountFormatter.string(fromByteCount: file.fileSize, countStyle: .file))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .contentShape(Rectangle())
                .onTapGesture {
                    NSWorkspace.shared.open(file.fileURL)
                }
            }
            .padding(.bottom, 10)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardPanel()
    }

    // MARK: - Badges

    private var locationBadge: some View {
        switch skill.location {
        case .personal:
            return badge(String(localized: "Personal"), color: .accentColor, icon: "person.crop.circle")
        case .legacyCommand:
            return badge(String(localized: "Legacy Command"), color: .orange, icon: "terminal")
        case .project(let path):
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

    // MARK: - Toolbar

    private var detailToolbar: some ToolbarContent {
        ToolbarItemGroup {
            Button {
                Task { try? await appState.toggleSkillEnabled(skill) }
            } label: {
                Label(skill.isEnabled ? "Disable" : "Enable",
                      systemImage: skill.isEnabled ? "pause.circle" : "play.circle")
            }
            .help(skill.isEnabled ? "Disable this skill" : "Enable this skill")
            .disabled(isPluginSkill)

            Button {
                NSWorkspace.shared.activateFileViewerSelecting([skill.directoryURL])
            } label: {
                Label("Show in Finder", systemImage: "folder")
            }
            .help("Reveal in Finder")

            Button {
                appState.exportSkill(skill)
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .disabled(skill.isLegacyCommand || isPluginSkill)
            .help(isPluginSkill ? "Plugin skills cannot be exported" : skill.isLegacyCommand ? "Legacy commands cannot be exported" : "Export this skill as a .skillpack archive")

            Button {
                appState.skillToEdit = skill
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .disabled(skill.isLegacyCommand || isPluginSkill)
            .help(isPluginSkill ? "Plugin skills are read-only" : skill.isLegacyCommand ? "Legacy commands cannot be edited here" : "Edit this skill")
        }
    }
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
