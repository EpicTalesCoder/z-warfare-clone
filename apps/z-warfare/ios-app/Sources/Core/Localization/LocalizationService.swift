import Foundation
import Combine

// Evidence: Extracted from 37_localization.txt -> Data/localization.json (2,745 keys x 12 languages)
public enum ZWLanguage: String, CaseIterable, Identifiable, Codable, Sendable {
    case en
    case fr
    case de
    case it
    case br
    case ru
    case zhs
    case es
    case zht
    case ja
    case ko
    case tr

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .en: return "English"
        case .fr: return "Français"
        case .de: return "Deutsch"
        case .it: return "Italiano"
        case .br: return "Português (BR)"
        case .ru: return "Русский"
        case .zhs: return "简体中文"
        case .es: return "Español"
        case .zht: return "繁體中文"
        case .ja: return "日本語"
        case .ko: return "한국어"
        case .tr: return "Türkçe"
        }
    }

    public static func systemDefault() -> ZWLanguage {
        let preferred = Locale.preferredLanguages.first?.lowercased() ?? "en"
        if preferred.hasPrefix("pt") { return .br }
        if preferred.hasPrefix("zh-hant") || preferred.hasPrefix("zh-tw") || preferred.hasPrefix("zh-hk") { return .zht }
        if preferred.hasPrefix("zh") { return .zhs }
        let two = String(preferred.prefix(2))
        return ZWLanguage(rawValue: two) ?? .en
    }
}

// Port of Mobirate localization owner backing unit/zombiepedia/synergy/GUI strings
public final class ZWLocalizationService: ObservableObject {
    public static let shared = ZWLocalizationService()

    private static let storageKey = "zw.selectedLanguage"

    @Published public var language: ZWLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: Self.storageKey)
        }
    }

    public private(set) var table: [String: [String: String]] = [:]

    public init(bundle: Bundle = .main) {
        if let saved = UserDefaults.standard.string(forKey: Self.storageKey),
           let parsed = ZWLanguage(rawValue: saved) {
            self.language = parsed
        } else {
            self.language = ZWLanguage.systemDefault()
        }
        loadTable(bundle: bundle)
    }

    public func loadTable(bundle: Bundle = .main) {
        let urls: [URL?] = [
            bundle.url(forResource: "localization", withExtension: "json", subdirectory: "Data"),
            bundle.url(forResource: "localization", withExtension: "json")
        ]
        for case let url? in urls {
            if let data = try? Data(contentsOf: url),
               let parsed = try? JSONDecoder().decode([String: [String: String]].self, from: data) {
                self.table = parsed
                return
            }
        }
    }

    public func text(_ key: String, fallback: String? = nil) -> String {
        if let entry = table[key] {
            if let localized = entry[language.rawValue], !localized.isEmpty {
                return localized
            }
            if let english = entry["en"], !english.isEmpty {
                return english
            }
        }
        return fallback ?? key
    }

    public func formatted(_ key: String, _ args: CVarArg..., fallback: String? = nil) -> String {
        var template = text(key, fallback: fallback)
        for (idx, arg) in args.enumerated() {
            template = template.replacingOccurrences(of: "{\(idx)}", with: "\(arg)")
        }
        return template
    }
}
