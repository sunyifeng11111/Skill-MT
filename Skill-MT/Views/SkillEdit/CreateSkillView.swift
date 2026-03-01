import SwiftUI
import AppKit

struct CreateSkillView: View {
    @Bindable var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.localization) private var localization

    @State private var rawName: String = ""
    @State private var descriptionText: String = ""
    @State private var argumentHint: String = ""
    @State private var userInvocable: Bool = true
    @State private var disableModelInvocation: Bool = false
    @State private var allowedTools: String = ""
    @State private var model: String = ""
    @State private var context: String = ""
    @State private var agent: String = ""
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
        let leaf = sanitizedName.isEmpty ? "<\(localization.string("name"))>" : sanitizedName
        return selectedLocation.basePath.appendingPathComponent(leaf).path
    }

    private var canCreate: Bool {
        !sanitizedName.isEmpty && !isCreating
    }

    var body: some View {
        VStack(spacing: 0) {
            sheetHeader

            Divider()

            HSplitView {
                ScrollView {
                    VStack(spacing: 0) {
                        identitySection
                        SkillEditorFieldsView(
                            hooksRaw: nil,
                            description: $descriptionText,
                            argumentHint: $argumentHint,
                            userInvocable: $userInvocable,
                            disableModelInvocation: $disableModelInvocation,
                            allowedTools: $allowedTools,
                            model: $model,
                            context: $context,
                            agent: $agent
                        )
                    }
                    .padding(.vertical, 8)
                }
                .frame(minWidth: 380)
                .layoutPriority(1)

                SkillEditorContentView(markdownContent: $markdownContent)
                    .padding(.vertical, 8)
                    .frame(minWidth: 520, maxWidth: .infinity, minHeight: 520, alignment: .topLeading)
                    .layoutPriority(2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .clipped()
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 8)

            if let err = createError {
                errorBanner(err)
            }

            Divider()

            sheetFooter
        }
        .frame(minWidth: 900, idealWidth: 1040, minHeight: 620)
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
                Text(localization.string("New Skill"))
                    .font(.title3)
                    .fontWeight(.semibold)
                Text(localization.string("Create a local skill"))
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
            Button(localization.string("Cancel")) { dismiss() }
                .keyboardShortcut(.escape)
            Spacer()
            Button {
                Task { await create() }
            } label: {
                if isCreating {
                    ProgressView().controlSize(.small)
                } else {
                    Text(localization.string("Create"))
                }
            }
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(!canCreate)
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    // MARK: - Sections

    private var identitySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader(localization.string("Identity"))

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(localization.string("name"))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                    TextField(localization.string("e.g. code-reviewer"), text: $rawName)
                        .font(.body)
                }

                if !rawName.isEmpty && sanitizedName != rawName {
                    Label(
                        String(format: localization.string("Will be saved as: %@"), sanitizedName),
                        systemImage: "info.circle"
                    )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(localization.string("location"))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Picker(localization.string("Save to"), selection: $selectedLocation) {
                        ForEach(availableLocations, id: \.self) { loc in
                            Text(locationLabel(loc)).tag(loc)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(localization.string("Output path"))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
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
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(16)
        }
        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.primary.opacity(0.07), lineWidth: 0.5)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 6)
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
            return String(
                format: localization.string("Project: %@"),
                URL(fileURLWithPath: path).lastPathComponent
            )
        case .codexProject(let path):
            return String(
                format: localization.string("Project: %@"),
                URL(fileURLWithPath: path).lastPathComponent
            )
        case .legacyCommand:
            return localization.string("Legacy Commands")
        case .plugin:
            return localization.string("Plugin")
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
            argumentHint: argumentHint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? nil : argumentHint.trimmingCharacters(in: .whitespacesAndNewlines),
            disableModelInvocation: disableModelInvocation,
            userInvocable: userInvocable,
            allowedTools: allowedTools.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? nil : allowedTools.trimmingCharacters(in: .whitespacesAndNewlines),
            model: model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? nil : model.trimmingCharacters(in: .whitespacesAndNewlines),
            context: context.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? nil : context.trimmingCharacters(in: .whitespacesAndNewlines),
            agent: agent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? nil : agent.trimmingCharacters(in: .whitespacesAndNewlines)
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
