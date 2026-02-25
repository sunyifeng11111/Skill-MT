import SwiftUI

struct SkillFilterBar: View {
    @Binding var searchText: String
    var scopeLabel: String = ""
    @Environment(\.localization) private var localization

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(localization.string("Search skills…"), text: $searchText)
                .textFieldStyle(.plain)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            } else if !scopeLabel.isEmpty {
                Text(scopeLabel)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background {
            filterBackground
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var filterBackground: some View {
        if #available(macOS 26, *) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.primary.opacity(0.06))
        } else {
            RoundedRectangle(cornerRadius: 10)
                .fill(.regularMaterial)
        }
    }
}
