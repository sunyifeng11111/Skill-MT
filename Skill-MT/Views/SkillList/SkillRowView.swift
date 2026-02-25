import SwiftUI

struct SkillRowView: View {
    let skill: Skill
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: skill.isLegacyCommand ? "terminal" : "bookmark.square")
                .font(.title2)
                .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                .frame(width: 32, height: 32)

            // Text content
            VStack(alignment: .leading, spacing: 4) {
                Text(skill.displayName)
                    .font(.headline)
                    .lineLimit(1)
                    // Explicit colour so it never becomes white on our custom background
                    .foregroundStyle(Color.primary)

                if let desc = skill.frontmatter.description {
                    Text(desc)
                        .font(.subheadline)
                        .foregroundStyle(Color.secondary)
                        .lineLimit(2)
                } else {
                    Text("No description")
                        .font(.subheadline)
                        .foregroundStyle(Color.secondary.opacity(0.6))
                        .italic()
                }
            }

            Spacer(minLength: 0)

            // Status badges
            VStack(alignment: .trailing, spacing: 4) {
                if !skill.isEnabled {
                    Image(systemName: "pause.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .help("Disabled — invisible to Claude Code")
                }
                if skill.frontmatter.disableModelInvocation {
                    Image(systemName: "bolt.slash")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .help("Model invocation disabled")
                }
                if !skill.frontmatter.userInvocable {
                    Image(systemName: "eye.slash")
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                        .help("Hidden from / menu")
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        )
        .contentShape(Rectangle())
        .opacity(skill.isEnabled ? 1.0 : 0.45)
    }
}
