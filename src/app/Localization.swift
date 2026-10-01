// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Ismoil Nosr
import Foundation

enum AppLanguage: String, CaseIterable {
    case system
    case english = "en"
    case russian = "ru"
    case simplifiedChinese = "zh-Hans"

    var displayName: String {
        switch self {
        case .system: return L("System default")
        case .english: return "English"
        case .russian: return "Русский"
        case .simplifiedChinese: return "简体中文"
        }
    }

    var locale: Locale {
        switch self {
        case .russian: return Locale(identifier: "ru_RU")
        case .simplifiedChinese: return Locale(identifier: "zh_Hans_CN")
        default: return Locale(identifier: "en_US")
        }
    }
}

/// Bundled .strings resources with a thread-safe, app-only language override.
/// Printer option identifiers, dimensions and user-entered label content stay unchanged.
enum Localization {
    static let preferenceKey = "interfaceLanguage"
    private static let lock = NSLock()
    private static var selection = AppLanguage(rawValue: UserDefaults.standard.string(forKey: preferenceKey) ?? "system") ?? .system
    private static let bundles: [AppLanguage: Bundle] = {
        var result: [AppLanguage: Bundle] = [:]
        for language in AppLanguage.allCases where language != .system {
            if let path = Bundle.main.path(forResource: language.rawValue, ofType: "lproj"), let bundle = Bundle(path: path) {
                result[language] = bundle
            }
        }
        return result
    }()

    static var preference: AppLanguage {
        lock.lock(); defer { lock.unlock() }
        return selection
    }

    static func configure(_ language: AppLanguage, persist: Bool = false, defaults: UserDefaults = .standard) {
        lock.lock(); selection = language; lock.unlock()
        if persist { defaults.set(language.rawValue, forKey: preferenceKey) }
    }

    static func resolve(_ language: AppLanguage, preferred: [String] = Locale.preferredLanguages) -> AppLanguage {
        guard language == .system else { return language }
        for name in preferred {
            let base = name.lowercased().replacingOccurrences(of: "_", with: "-")
            if base == "ru" || base.hasPrefix("ru-") { return .russian }
            if base == "zh" || base.hasPrefix("zh-") { return .simplifiedChinese }
            if base == "en" || base.hasPrefix("en-") { return .english }
        }
        return .english
    }

    static var effectiveLanguage: AppLanguage { resolve(preference) }
    static var locale: Locale { effectiveLanguage.locale }
    static var documentationURL: URL {
        let root = "https://github.com/ismoil-nosr/xprinter-macos"
        switch effectiveLanguage {
        case .russian: return URL(string: root + "/blob/main/docs/README.ru.md")!
        case .simplifiedChinese: return URL(string: root + "/blob/main/docs/README.zh-CN.md")!
        default: return URL(string: root)!
        }
    }

    static func text(_ key: String) -> String {
        let selected = bundles[effectiveLanguage]?.localizedString(forKey: key, value: key, table: "Localizable") ?? key
        if selected != key || effectiveLanguage == .english { return selected }
        return bundles[.english]?.localizedString(forKey: key, value: key, table: "Localizable") ?? key
    }

    static func formatted(_ key: String, _ arguments: [CVarArg]) -> String {
        String(format: text(key), locale: locale, arguments: arguments)
    }

    static func number(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale; formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false; formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    static func selfTest() throws {
        let saved = preference
        defer { configure(saved) }
        guard resolve(.system, preferred: ["ru-UZ", "en"]) == .russian,
              resolve(.system, preferred: ["zh-Hans-CN"]) == .simplifiedChinese,
              resolve(.system, preferred: ["zh-Hant-TW"]) == .simplifiedChinese,
              resolve(.system, preferred: ["fr", "en-GB"]) == .english,
              resolve(.system, preferred: ["fr"]) == .english,
              resolve(.russian, preferred: ["en"]) == .russian else {
            throw LabelFailure.message("System language resolution failed.")
        }
        for (language, expected) in [(AppLanguage.english, "Label size"), (.russian, "Размер этикетки"), (.simplifiedChinese, "标签尺寸")] {
            configure(language)
            guard bundles[language] != nil, L("Label size") == expected,
                  L("untranslated-test-key") == "untranslated-test-key",
                  !LF("Copies: %d", 12).contains("%d"),
                  LabelFailure.formatted("CSV row %d has the wrong number of columns.", [3]).localizedDescription.contains("3") else {
                throw LabelFailure.message("Localized resources or format arguments failed.")
            }
            var invalid = LabelConfig(); invalid.width = 200
            do { try invalid.validate(); throw LabelFailure.message("Invalid dimensions were accepted.") }
            catch let error as LabelFailure {
                guard error.localizedDescription == L("Choose a width from 20 to 76 mm and height from 10 to 1,000 mm.") else { throw error }
            }
            if language == .russian && number(58.5) != "58,5" { throw LabelFailure.message("Localized decimal formatting failed.") }
        }
        print("English, Russian and Simplified Chinese resources, errors, formatting and system fallback PASS")
    }
}

func L(_ key: String) -> String { Localization.text(key) }
func LF(_ key: String, _ arguments: CVarArg...) -> String { Localization.formatted(key, arguments) }
