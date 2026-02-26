import SwiftUI

struct ImportSkillView: View {
    @Bindable var appState: AppState
    let package: SkillPackage
    @Environment(\.dismiss) private var dismiss
    @Environment(\.localization) private var localization

    @State private var skillName: String
    @State private var selectedLocation: SkillLocation
    @State private var isImporting: Bool = false
    @State private var importError: String?

    init(package: SkillPackage, appState: AppState) {
        self.package = package
        self.appState = appState
        _skillName = State(initialValue: package.name)
        let initialLocation: SkillLocation = {
            switch appState.selectedProvider {
            case .claude:
                if case .project = appState.preferredCreateLocation {
                    return appState.preferredCreateLocation
                }
                return .personal
            case .codex:
                if case .codexProject = appState.preferredCreateLocation {
                    return appState.preferredCreateLocation
                }
                return .codexPersonal
            }
        }()
        _selectedLocation = State(
            initialValue: initialLocation
        )
    }

    private var availableLocations: [SkillLocation] {
        switch appState.selectedProvider {
        case .claude:
            var locations: [SkillLocation] = [.personal]
            locations += appState.monitoredProjectURLs.map { .project(path: $0.path) }
            return locations
        case .codex:
            var locations: [SkillLocation] = [.codexPersonal]
            locations += appState.monitoredProjectURLs.map { .codexProject(path: $0.path) }
            return locations
        }
    }

    private var nameError: String? {
        let trimmed = skillName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return localization.string("Name cannot be empty") }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        if !trimmed.unicodeScalars.allSatisfy({ allowed.contains($0) }) {
            return localization.string("Only letters, numbers, hyphens, and underscores are allowed")
        }
        return nil
    }

    var body: some View {
        VStack(spacing: 0) {
            sheetHeader

            Divider()

            ScrollView {
                VStack(spacing: 0) {
                    previewSection
                    settingsSection
                }
                .padding(.vertical, 8)
            }

            if let err = importError {
                errorBanner(err)
            }

            Divider()

            sheetFooter
        }
        .frame(minWidth: 480, idealWidth: 540, minHeight: 380)
        .onAppear {
            syncSelectedLocation()
        }
        .onChange(of: appState.monitoredProjectURLs) { _, _ in
            syncSelectedLocation()
        }
        .onChange(of: appState.selectedProvider) { _, _ in
            syncSelectedLocation()
        }
    }

    // MARK: - Header / Footer

    private var sheetHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(localization.string("Import Skill"))
                    .font(.title3)
                    .fontWeight(.semibold)
                Text(localization.string("Review and configure the skill before importing"))
                    .font(.caption)
                    .foregroundStyle(.secondary)            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    private var sheetFooter: some View {
        HStack {
            Button("Cancel") { dismiss() }
                .keyboardShortcut(.escape)
            Spacer()
            Button {
                Task { await doImport() }
            } label: {
                if isImporting {
                    ProgressView().controlSize(.small)
                } else {
                    Text(localization.string("Import"))
                }
            }
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(nameError != nil || isImporting)
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    // MARK: - Preview Section

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel(localization.string("Preview"))

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "bookmark.square.fill")
                        .font(.title3)
                        .foregroundStyle(.tint)
                    Text(package.name)
                        .font(.headline)
                }

                if let desc = package.frontmatter.description, !desc.isEmpty {
                    Text(desc)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                let badges = buildBadges()
                if !badges.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(badges, id: \.label) { badge in
                            badgeView(badge.label, color: badge.color)
                        }
                    }
                }

                if !package.supportingFiles.isEmpty {
                    Text(String(format: localization.string("%d supporting file(s)"), package.supportingFiles.count))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.primary.opacity(0.07), lineWidth: 0.5)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }

    // MARK: - Settings Section

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel(localization.string("Settings"))

            VStack(spacing: 0) {
                // Name row
                HStack(alignment: .top, spacing: 8) {
                    Text(localization.string("name"))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.primary)
                        .frame(width: 140, alignment: .leading)
                        .padding(.top, 3)
                    VStack(alignment: .leading, spacing: 3) {
                        TextField("Skill name", text: $skillName)
                            .font(.caption)
                        if let err = nameError {
                            Text(err)
                                .font(.caption2)
                                .foregroundStyle(.red)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

                // Location row (only when multiple locations are available)
                if availableLocations.count > 1 {
                    Divider().padding(.leading, 16)
                    HStack(alignment: .top, spacing: 8) {
                        Text(localization.string("location"))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.primary)
                            .frame(width: 140, alignment: .leading)
                            .padding(.top, 3)
                        Picker("", selection: $selectedLocation) {
                            ForEach(availableLocations, id: \.self) { loc in
                                Text(locationLabel(loc)).tag(loc)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .font(.caption)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
            }
            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.primary.opacity(0.07), lineWidth: 0.5)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }

    // MARK: - Helpers

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 6)
    }

    private func badgeView(_ label: String, color: Color) -> some View {
        Text(label)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.12), in: Capsule())
            .foregroundStyle(color)
    }

    private struct BadgeInfo: Hashable { let label: String; let color: Color }

    private func locationLabel(_ loc: SkillLocation) -> String {
        switch loc {
        case .personal, .codexPersonal:
            return localization.string("Personal Skills")
        case .codexSystem:
            return localization.string("System Skills")
        case .project(let path):
            return "Project: \(URL(fileURLWithPath: path).lastPathComponent)"
        case .codexProject(let path):
            return "Project: \(URL(fileURLWithPath: path).lastPathComponent)"
        case .legacyCommand:
            return localization.string("Legacy Commands")
        case .plugin(_, let name, _):
            return name
        }
    }

    private func buildBadges() -> [BadgeInfo] {
        var result: [BadgeInfo] = []
        if package.frontmatter.disableModelInvocation {
            result.append(.init(label: "Auto-off", color: .orange))
        }
        if !package.frontmatter.userInvocable {
            result.append(.init(label: "Hidden", color: .secondary))
        }
        if package.frontmatter.context == "fork" {
            result.append(.init(label: "Fork", color: .purple))
        }
        return result
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
            Text(message).font(.caption).foregroundStyle(.red)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(Color.red.opacity(0.08))
    }

    // MARK: - Import Action

    @MainActor
    private func doImport() async {
        isImporting = true
        importError = nil
        let name = skillName.trimmingCharacters(in: .whitespacesAndNewlines)
        let location = resolvedLocation()
        do {
            try await appState.importSkill(package, name: name, location: location)
            dismiss()
        } catch {
            importError = error.localizedDescription
            isImporting = false
        }
    }

    @MainActor
    private func syncSelectedLocation() {
        selectedLocation = resolvedLocation()
    }

    private func resolvedLocation() -> SkillLocation {
        if availableLocations.contains(selectedLocation) {
            return selectedLocation
        }
        return availableLocations.first ?? .personal
    }
}
