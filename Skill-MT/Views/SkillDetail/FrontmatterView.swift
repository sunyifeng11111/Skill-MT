import SwiftUI

struct FrontmatterView: View {
    let frontmatter: SkillFrontmatter

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Frontmatter")

            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.element.key) { index, row in
                    frontmatterRow(key: row.key, value: row.value, isSet: row.isSet, multiline: row.multiline)
                    if index < rows.count - 1 {
                        Divider()
                            .padding(.leading, 16)
                    }
                }
            }
        }
    }

    // MARK: - Rows Data

    private struct Row {
        let key: String
        let value: String
        let isSet: Bool
        var multiline: Bool = false
    }

    private var rows: [Row] {
        [
            Row(key: "name",                      value: frontmatter.name ?? "(from directory)",          isSet: frontmatter.name != nil),
            Row(key: "description",               value: frontmatter.description ?? "—",                  isSet: frontmatter.description != nil, multiline: true),
            Row(key: "argument-hint",             value: frontmatter.argumentHint ?? "—",                 isSet: frontmatter.argumentHint != nil),
            Row(key: "disable-model-invocation",  value: frontmatter.disableModelInvocation ? "true" : "false", isSet: true),
            Row(key: "user-invocable",            value: frontmatter.userInvocable ? "true" : "false",    isSet: true),
            Row(key: "allowed-tools",             value: frontmatter.allowedTools ?? "—",                 isSet: frontmatter.allowedTools != nil),
            Row(key: "model",                     value: frontmatter.model ?? "—",                        isSet: frontmatter.model != nil),
            Row(key: "context",                   value: frontmatter.context ?? "—",                      isSet: frontmatter.context != nil),
            Row(key: "agent",                     value: frontmatter.agent ?? "—",                        isSet: frontmatter.agent != nil),
            Row(key: "hooks",                     value: frontmatter.hooksRaw != nil ? "(configured)" : "—", isSet: frontmatter.hooksRaw != nil),
        ]
    }

    // MARK: - Sub-views

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

    private func frontmatterRow(key: String, value: String, isSet: Bool, multiline: Bool) -> some View {
        HStack(alignment: multiline ? .top : .center) {
            Text(key)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(isSet ? .primary : .tertiary)
                .frame(width: 200, alignment: .leading)
            Text(value)
                .font(.caption)
                .foregroundStyle(isSet ? .primary : .tertiary)
                .lineLimit(multiline ? nil : 1)
                .truncationMode(.tail)
                .fixedSize(horizontal: false, vertical: multiline)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }
}
