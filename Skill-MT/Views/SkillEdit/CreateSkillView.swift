import SwiftUI

struct CreateSkillView: View {
    @Bindable var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var rawName: String = ""
    @State private var description: String = ""
    @State private var userInvocable: Bool = true
    @State private var disableModelInvocation: Bool = false
    @State private var markdownContent: String = ""
    @State private var selectedLocationIndex: Int = 0
    @State private var isCreating: Bool = false
    @State private var createError: String?

    private var availableLocations: [SkillLocation] {
        switch appState.selectedProvider {
        case .claude:
            var locations: [SkillLocation] = [.personal]
            locations += appState.monitoredProjectURLs.map { .project(path: $0.path) }
            return locations
        case .codex:
            return [.codexPersonal]
        }
    }

    private var sanitizedName: String {
        rawName
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
    }

    private var selectedLocation: SkillLocation {
        let locs = availableLocations
        guard selectedLocationIndex < locs.count else { return .personal }
        return locs[selectedLocationIndex]
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

            TextField("Description", text: $description, prompt: Text("One-line description (optional)"), axis: .vertical)
                .lineLimit(2...4)
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
            Picker("Save to", selection: $selectedLocationIndex) {
                ForEach(Array(availableLocations.enumerated()), id: \.offset) { index, loc in
                    Text(locationLabel(loc)).tag(index)
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
            return "Personal Skills"
        case .codexPersonal:
            return "Personal Skills"
        case .codexSystem:
            return "System Skills"
        case .project(let path):
            return "Project: \(URL(fileURLWithPath: path).lastPathComponent)"
        case .legacyCommand:
            return "Legacy Commands"
        case .plugin:
            return "Plugin"
        }
    }

    @MainActor
    private func create() async {
        let name = sanitizedName
        guard !name.isEmpty else { return }

        isCreating = true
        createError = nil

        let frontmatter = SkillFrontmatter(
            description: description.isEmpty ? nil : description,
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
}
