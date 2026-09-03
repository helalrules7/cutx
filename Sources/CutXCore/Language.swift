import Foundation

/// The languages CutX ships. `automatic` follows the system.
public enum Language: String, CaseIterable, Sendable {
    case automatic, english, arabic, spanish, french, german
    case portugueseBrazil, russian, chineseSimplified, japanese, turkish, italian

    /// The `.lproj` directory name. Empty for `automatic`.
    public var code: String {
        switch self {
        case .automatic: return ""
        case .english: return "en"
        case .arabic: return "ar"
        case .spanish: return "es"
        case .french: return "fr"
        case .german: return "de"
        case .portugueseBrazil: return "pt-BR"
        case .russian: return "ru"
        case .chineseSimplified: return "zh-Hans"
        case .japanese: return "ja"
        case .turkish: return "tr"
        case .italian: return "it"
        }
    }

    /// Shown in the picker. A language names itself in its own script — a Russian
    /// speaker scanning the list looks for "Русский", not for "Russian".
    public var nativeName: String {
        switch self {
        case .automatic: return "Automatic"
        case .english: return "English"
        case .arabic: return "العربية"
        case .spanish: return "Español"
        case .french: return "Français"
        case .german: return "Deutsch"
        case .portugueseBrazil: return "Português (BR)"
        case .russian: return "Русский"
        case .chineseSimplified: return "中文 (简体)"
        case .japanese: return "日本語"
        case .turkish: return "Türkçe"
        case .italian: return "Italiano"
        }
    }

    public var isRightToLeft: Bool { self == .arabic }
}
