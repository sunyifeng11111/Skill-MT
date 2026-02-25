import SwiftUI

struct EditSkillView: View {
    let skill: Skill
    @Bindable var appState: AppState
    @Environment(\.dismiss) private var dismiss

    // Frontmatter fields
    @State private var description: String
    @State private var argumentHint: String
    @State private var userInvocable: Bool
    @State private var disableModelInvocation: Bool
    @State private var allowedTools: String
    @State private var model: String
    @State private var context: String
    @State private var agent: String
    // Markdown body
    @State private var markdownContent: String

    @State private var isSaving: Bool = false
    @State private var saveError: String?

    init(skill: Skill, appState: AppState) {
        self.skill = skill
        self.appState = appState
        let fm = skill.frontmatter
        _description          = State(initialValue: fm.description ?? "")
        _argumentHint         = State(initialValue: fm.argumentHint ?? "")
        _userInvocable        = State(initialValue: fm.userInvocable)
        _disableModelInvocation = State(initialValue: fm.disableModelInvocation)
        _allowedTools         = State(initialValue: fm.allowedTools ?? "")
        _model                = State(initialValue: fm.model ?? "")
        _context              = State(initialValue: fm.context ?? "")
        _agent                = State(initialValue: fm.agent ?? "")
        _markdownContent      = State(initialValue: skill.markdownContent)
    }

    private var hasChanges: Bool {
        let fm = skill.frontmatter
        return description          != (fm.description ?? "")           ||
               argumentHint         != (fm.argumentHint ?? "")          ||
               userInvocable        != fm.userInvocable                 ||
               disableModelInvocation != fm.disableModelInvocation      ||
               allowedTools         != (fm.allowedTools ?? "")          ||
               model                != (fm.model ?? "")                 ||
               context              != (fm.context ?? "")               ||
               agent                != (fm.agent ?? "")                 ||
               markdownContent      != skill.markdownContent
    }

    var body: some View {
        VStack(spacing: 0) {
            sheetHeader

            Divider()

            ScrollView {
                VStack(spacing: 0) {
                    frontmatterSection
                    contentSection
                }
                .padding(.vertical, 8)
            }

            if let err = saveError {
                errorBanner(err)
            }

            Divider()

            sheetFooter
        }
        .frame(minWidth: 560, idealWidth: 640, minHeight: 520)
    }

    // MARK: - Header / Footer

    private var sheetHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Edit Skill")
                    .font(.title3)
                    .fontWeight(.semibold)
                Text(skill.skillFileURL.path(percentEncoded: false))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
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
                Task { await save() }
            } label: {
                if isSaving {
                    ProgressView().controlSize(.small)
                } else {
                    Text("Save")
                }
            }
            .keyboardShortcut("s", modifiers: .command)
            .disabled(!hasChanges || isSaving)
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    // MARK: - Sections

    private var frontmatterSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Frontmatter")

            VStack(spacing: 0) {
                editRow(label: "description") {
                    TextField("One-line description", text: $description, axis: .vertical)
                        .lineLimit(2...5)
                }
                Divider().padding(.leading, 16)
                editRow(label: "argument-hint") {
                    TextField("Argument hint (optional)", text: $argumentHint)
                }
                Divider().padding(.leading, 16)
                editRow(label: "allowed-tools") {
                    TextField("e.g. Read, Write, Bash", text: $allowedTools)
                }
                Divider().padding(.leading, 16)
                editRow(label: "model") {
                    TextField("Model override (optional)", text: $model)
                }
                Divider().padding(.leading, 16)
                editRow(label: "context") {
                    TextField("e.g. fork", text: $context)
                }
                Divider().padding(.leading, 16)
                editRow(label: "agent") {
                    TextField("Agent name (optional)", text: $agent)
                }
                Divider().padding(.leading, 16)
                toggleRow(label: "user-invocable", value: $userInvocable)
                Divider().padding(.leading, 16)
                toggleRow(label: "disable-model-invocation", value: $disableModelInvocation)

                if let hooks = skill.frontmatter.hooksRaw {
                    Divider().padding(.leading, 16)
                    hooksRow(raw: hooks)
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

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Content")

            HighlightedTextView(text: $markdownContent)
                .frame(minHeight: 200)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.primary.opacity(0.07), lineWidth: 0.5)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
        }
    }

    // MARK: - Row Helpers

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

    private func editRow<Field: View>(label: String, @ViewBuilder field: () -> Field) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.primary)
                .frame(width: 200, alignment: .leading)
                .padding(.top, 3)
            field()
                .font(.caption)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func toggleRow(label: String, value: Binding<Bool>) -> some View {
        HStack {
            Text(label)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.primary)
                .frame(width: 200, alignment: .leading)
            Toggle("", isOn: value)
                .labelsHidden()
                .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func hooksRow(raw: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("hooks")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.primary)
                .frame(width: 200, alignment: .leading)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(raw.trimmingCharacters(in: .newlines))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                Text("Edit hooks directly in SKILL.md")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
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

    // MARK: - Save

    @MainActor
    private func save() async {
        isSaving = true
        saveError = nil

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
            dismiss()
        } catch {
            saveError = error.localizedDescription
            isSaving = false
        }
    }
}
