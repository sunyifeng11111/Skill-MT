import SwiftUI
import AppKit

enum SettingsSection: String, CaseIterable, Identifiable {
    case general
    case paths

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .paths: return "folder"
        }
    }

    var titleKey: String {
        switch self {
        case .general: return "General"
        case .paths: return "Paths"
        }
    }
}

struct SettingsView: View {
    @Bindable var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.localization) private var localization
    @State private var appearance: AppAppearance = AppAppearance.load()
    @State private var selectedSection: SettingsSection? = .general
    @State private var claudeHomeDraft: String = ""
    @State private var codexHomeDraft: String = ""

    var body: some View {
        HStack(spacing: 0) {
            List(SettingsSection.allCases, selection: $selectedSection) { section in
                Label(localization.string(section.titleKey), systemImage: section.icon)
                    .tag(section)
            }
            .listStyle(.sidebar)
            .frame(width: 160)

            Divider()

            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(localization.string("Settings"))
                            .font(.title3)
                            .fontWeight(.semibold)
                        Text(localization.string("Skill-MT preferences"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)

                Divider()

                ScrollView {
                    Group {
                        switch selectedSection ?? .general {
                        case .general:
                            generalSection
                        case .paths:
                            pathsSection
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 20)
                }

                Divider()

                HStack {
                    Spacer()
                    Button(localization.string("Done")) { dismiss() }
                        .keyboardShortcut(.return, modifiers: .command)
                        .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
        }
        .frame(width: 700, height: 460)
        .onAppear {
            claudeHomeDraft = appState.settings.claudeHomePath
            codexHomeDraft = appState.settings.codexHomePath
        }
    }

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(localization.string("Language"))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                HStack(spacing: 12) {
                    ForEach(AppLanguage.allCases) { lang in
                        languageButton(lang)
                    }
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text(localization.string("Appearance"))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                HStack(spacing: 12) {
                    ForEach(AppAppearance.allCases) { mode in
                        appearanceButton(mode)
                    }
                }
            }

            Divider()

            HStack {
                Text(localization.string("Version"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(appState.localVersion)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(localization.string("Latest"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(appState.latestVersionText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    Button(localization.string("Check for Updates…")) {
                        Task { await appState.checkForUpdates(manual: true) }
                    }
                    .disabled(appState.isCheckingUpdates)

                    if appState.latestReleaseInfo != nil {
                        Button(localization.string("Download Update")) {
                            Task { await appState.downloadAndOpenLatestUpdate() }
                        }
                    }
                }

                if let status = appState.updateStatusMessage {
                    Text(status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(12)
            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
        }
    }

    private var pathsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(localization.string("Directories"))
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)

            pathEditorRow(
                title: localization.string("Claude Home Directory"),
                text: $claudeHomeDraft,
                onChoose: { chooseDirectory(for: .claude) },
                onReset: { resetPath(for: .claude) },
                onSave: { savePath(for: .claude) }
            )

            pathEditorRow(
                title: localization.string("Codex Home Directory"),
                text: $codexHomeDraft,
                onChoose: { chooseDirectory(for: .codex) },
                onReset: { resetPath(for: .codex) },
                onSave: { savePath(for: .codex) }
            )

            Text(localization.string("Project skills path remains <project>/.claude/skills and is not overridden by this setting."))
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private func pathEditorRow(
        title: String,
        text: Binding<String>,
        onChoose: @escaping () -> Void,
        onReset: @escaping () -> Void,
        onSave: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)

            HStack(spacing: 8) {
                TextField("", text: text)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { onSave() }

                Button(localization.string("Choose…"), action: onChoose)
                Button(localization.string("Reset"), action: onReset)
                    .foregroundStyle(.secondary)
            }

            if !directoryExists(path: text.wrappedValue) {
                Text(localization.string("Path does not exist yet. Skills list will be empty until created."))
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(12)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
    }

    private enum PathTarget {
        case claude
        case codex
    }

    private func chooseDirectory(for target: PathTarget) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = localization.string("Choose…")

        guard panel.runModal() == .OK, let url = panel.url else { return }

        switch target {
        case .claude:
            claudeHomeDraft = url.path
        case .codex:
            codexHomeDraft = url.path
        }

        savePath(for: target)
    }

    private func resetPath(for target: PathTarget) {
        switch target {
        case .claude:
            appState.settings.resetClaudeHome()
            claudeHomeDraft = appState.settings.claudeHomePath
        case .codex:
            appState.settings.resetCodexHome()
            codexHomeDraft = appState.settings.codexHomePath
        }

        Task { await appState.applySettingsAndReload() }
    }

    private func savePath(for target: PathTarget) {
        switch target {
        case .claude:
            appState.settings.saveClaudeHome(claudeHomeDraft)
            claudeHomeDraft = appState.settings.claudeHomePath
        case .codex:
            appState.settings.saveCodexHome(codexHomeDraft)
            codexHomeDraft = appState.settings.codexHomePath
        }

        Task { await appState.applySettingsAndReload() }
    }

    private func directoryExists(path: String) -> Bool {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(
            atPath: appState.settings.expandedPath(trimmed).path,
            isDirectory: &isDirectory
        ) && isDirectory.boolValue
    }

    private func languageButton(_ lang: AppLanguage) -> some View {
        let isSelected = localization.language == lang
        return Button {
            localization.language = lang
        } label: {
            Text(lang.displayName)
                .font(.subheadline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            isSelected ? Color.accentColor.opacity(0.15) : Color.primary.opacity(0.05),
            in: RoundedRectangle(cornerRadius: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5)
        )
        .foregroundStyle(isSelected ? Color.accentColor : .primary)
    }

    private func appearanceButton(_ mode: AppAppearance) -> some View {
        let isSelected = appearance == mode
        return Button {
            appearance = mode
            mode.apply()
        } label: {
            VStack(spacing: 6) {
                Image(systemName: mode.icon)
                    .font(.title2)
                Text(localization.string(mode.labelKey))
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            isSelected ? Color.accentColor.opacity(0.15) : Color.primary.opacity(0.05),
            in: RoundedRectangle(cornerRadius: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5)
        )
        .foregroundStyle(isSelected ? Color.accentColor : .primary)
    }
}

// MARK: - Appearance

enum AppAppearance: String, CaseIterable, Identifiable {
    case system = "system"
    case light  = "light"
    case dark   = "dark"

    var id: String { rawValue }

    var labelKey: String {
        switch self {
        case .system: return "System"
        case .light:  return "Light"
        case .dark:   return "Dark"
        }
    }

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light:  return "sun.max"
        case .dark:   return "moon"
        }
    }

    func apply() {
        UserDefaults.standard.set(rawValue, forKey: "appAppearance")
        let target: NSAppearance? = switch self {
        case .system: nil
        case .light:  NSAppearance(named: .aqua)
        case .dark:   NSAppearance(named: .darkAqua)
        }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            ctx.allowsImplicitAnimation = true
            NSApp.appearance = target
        }
    }

    static func load() -> AppAppearance {
        let saved = UserDefaults.standard.string(forKey: "appAppearance") ?? ""
        return AppAppearance(rawValue: saved) ?? .system
    }
}
