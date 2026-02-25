import SwiftUI
import AppKit

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.localization) private var localization
    @State private var appearance: AppAppearance = AppAppearance.load()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(localization.string("Settings"))
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text(localization.string("Skill-MT preferences"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            Divider()

            VStack(alignment: .leading, spacing: 16) {
                // Language
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

                // Appearance
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

                // Version
                HStack {
                    Text(localization.string("Version"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)

            Spacer()

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
        .frame(width: 420, height: 380)
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
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.primary.opacity(0.05),
                    in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8)
            .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5))
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
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.primary.opacity(0.05),
                    in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8)
            .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5))
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
