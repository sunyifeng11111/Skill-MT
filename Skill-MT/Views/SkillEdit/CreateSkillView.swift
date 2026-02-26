import SwiftUI
import AppKit

struct CreateSkillView: View {
    @Bindable var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.localization) private var localization

    @State private var rawName: String = ""
    @State private var descriptionText: String = ""
    @State private var userInvocable: Bool = true
    @State private var disableModelInvocation: Bool = false
    @State private var markdownContent: String = ""
    @State private var selectedLocation: SkillLocation = .personal
    @State private var isCreating: Bool = false
    @State private var createError: String?
    @State private var didInitializeLocation: Bool = false

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

    private var sanitizedName: String {
        rawName
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
    }

    private var previewPath: String {
        let leaf = sanitizedName.isEmpty ? "<name>" : sanitizedName
        return selectedLocation.basePath.appendingPathComponent(leaf).path
    }

    private var canCreate: Bool {
        !sanitizedName.isEmpty && !isCreating
    }

    var body: some View {
        VStack(spacing: 0) {
            sheetHeader

            Divider()

            Form {
                identitySection
                settingsSection
                if availableLocations.count > 1 {
                    locationSection
                }
                contentSection
                pathPreviewSection
            }
            .formStyle(.grouped)

            if let err = createError {
                errorBanner(err)
            }

            Divider()

            sheetFooter
        }
        .frame(minWidth: 480, idealWidth: 520, minHeight: 440)
        .onAppear {
            syncSelectedLocation(forcePreferred: true)
            didInitializeLocation = true
        }
        .onChange(of: appState.selectedProvider) { _, _ in
            syncSelectedLocation(forcePreferred: true)
        }
        .onChange(of: appState.monitoredProjectURLs) { _, _ in
            syncSelectedLocation(forcePreferred: false)
        }
        .onChange(of: selectedLocation) { _, newValue in
            if didInitializeLocation {
                appState.preferredCreateLocation = newValue
            }
        }
    }

    // MARK: - Header / Footer

    private var sheetHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("New Skill")
                    .font(.title3)
                    .fontWeight(.semibold)
                Text("Create a local skill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
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
                Task { await create() }
            } label: {
                if isCreating {
                    ProgressView().controlSize(.small)
                } else {
                    Text("Create")
                }
            }
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(!canCreate)
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    // MARK: - Form Sections

    private var identitySection: some View {
        Section("Identity") {
            TextField("Skill name", text: $rawName, prompt: Text("e.g. code-reviewer"))

            if !rawName.isEmpty && sanitizedName != rawName {
                Label("Will be saved as: \(sanitizedName)", systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            TextField("Description", text: $descriptionText, prompt: Text("One-line description (optional)"))
        }
    }

    private var settingsSection: some View {
        Section("Settings") {
            Toggle("User-invocable", isOn: $userInvocable)
            Toggle("Disable model invocation", isOn: $disableModelInvocation)
        }
    }

    private var locationSection: some View {
        Section("Location") {
            Picker("Save to", selection: $selectedLocation) {
                ForEach(availableLocations, id: \.self) { loc in
                    Text(locationLabel(loc)).tag(loc)
                }
            }
        }
    }

    private var contentSection: some View {
        Section("Initial Content") {
            HighlightedTextView(text: $markdownContent)
                .frame(minHeight: 80)
        }
    }

    private var pathPreviewSection: some View {
        Section {
            HStack(spacing: 6) {
                Image(systemName: "folder")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                Text(previewPath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .lineLimit(2)
                    .truncationMode(.middle)
            }
        } header: {
            Text("Output path")
        }
    }

    // MARK: - Error Banner

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            Text(message)
                .font(.caption)
                .foregroundStyle(.red)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(Color.red.opacity(0.08))
    }

    // MARK: - Helpers

    private func locationLabel(_ loc: SkillLocation) -> String {
        switch loc {
        case .personal:
            return localization.string("Personal Skills")
        case .codexPersonal:
            return localization.string("Personal Skills")
        case .codexSystem:
            return localization.string("System Skills")
        case .project(let path):
            return "Project: \(URL(fileURLWithPath: path).lastPathComponent)"
        case .codexProject(let path):
            return "Project: \(URL(fileURLWithPath: path).lastPathComponent)"
        case .legacyCommand:
            return localization.string("Legacy Commands")
        case .plugin:
            return "Plugin"
        }
    }

    @MainActor
    private func create() async {
        // Ensure active text input (IME composition) is committed before reading state.
        NSApp.keyWindow?.makeFirstResponder(nil)

        let name = sanitizedName
        guard !name.isEmpty else { return }
        syncSelectedLocation(forcePreferred: false)

        isCreating = true
        createError = nil
        let normalizedDescription = descriptionText.trimmingCharacters(in: .whitespacesAndNewlines)

        let frontmatter = SkillFrontmatter(
            name: name,
            description: normalizedDescription.isEmpty ? nil : normalizedDescription,
            disableModelInvocation: disableModelInvocation,
            userInvocable: userInvocable
        )

        do {
            try await appState.createSkill(
                name: name,
                frontmatter: frontmatter,
                markdownContent: markdownContent,
                location: selectedLocation
            )
            dismiss()
        } catch {
            createError = error.localizedDescription
            isCreating = false
        }
    }

    @MainActor
    private func syncSelectedLocation(forcePreferred: Bool) {
        let locs = availableLocations
        if locs.isEmpty {
            selectedLocation = .personal
            return
        }
        let preferred = appState.preferredCreateLocation
        if forcePreferred, locs.contains(preferred) {
            selectedLocation = preferred
            return
        }
        if locs.contains(selectedLocation) {
            return
        }
        selectedLocation = locs.contains(preferred) ? preferred : locs[0]
    }
}
