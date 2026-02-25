import SwiftUI

// MARK: - Supported Languages

enum AppLanguage: String, CaseIterable, Identifiable {
    case system = "system"
    case english = "en"
    case chinese = "zh-Hans"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system:  return "System Default"
        case .english: return "English"
        case .chinese: return "中文"
        }
    }

    var locale: Locale {
        switch self {
        case .system:  return .current
        case .english: return Locale(identifier: "en")
        case .chinese: return Locale(identifier: "zh-Hans")
        }
    }

    var bundle: Bundle {
        guard self != .system else { return .main }
        guard let path = Bundle.main.path(forResource: rawValue, ofType: "lproj"),
              let b = Bundle(path: path) else { return .main }
        return b
    }
}

// MARK: - Manager

@Observable
final class LocalizationManager {

    private static let key = "appLanguage"

    var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: Self.key)
        }
    }

    init() {
        let saved = UserDefaults.standard.string(forKey: Self.key) ?? ""
        language = AppLanguage(rawValue: saved) ?? .system
    }

    var locale: Locale { language.locale }
    var bundle: Bundle { language.bundle }

    func string(_ key: String) -> String {
        bundle.localizedString(forKey: key, value: key, table: nil)
    }
}

// MARK: - Environment Key

private struct LocalizationManagerKey: EnvironmentKey {
    static let defaultValue = LocalizationManager()
}

extension EnvironmentValues {
    var localization: LocalizationManager {
        get { self[LocalizationManagerKey.self] }
        set { self[LocalizationManagerKey.self] = newValue }
    }
}
