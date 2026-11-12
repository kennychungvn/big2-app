import Foundation

/// Which wording and default 計分 table the interface uses.
///
/// - `hongKong`: Cantonese 鋤大D wording (計分、炒、入今局), default table 香港炒.
/// - `taiwan`: Taiwan Mandarin 大老二 wording (記分、加倍、記這一局), default table 台灣常見.
public enum InterfaceRegion: String, Codable, CaseIterable, Sendable {
    case hongKong
    case taiwan

    /// `.lproj` folder name used for `Localizable.strings` lookups in the app target.
    public var localizationIdentifier: String {
        switch self {
        case .hongKong: return "zh-Hant-HK"
        case .taiwan: return "zh-Hant-TW"
        }
    }

    /// Locale for SwiftUI `\.locale` and date formatting.
    public var localeIdentifier: String {
        switch self {
        case .hongKong: return "zh_Hant_HK"
        case .taiwan: return "zh_Hant_TW"
        }
    }

    public var locale: Locale { Locale(identifier: localeIdentifier) }

    /// Preset picked for a brand-new player, or after switching region away from the other default.
    public var defaultRulePreset: RulePreset {
        switch self {
        case .hongKong: return .hongKongDefault
        case .taiwan: return .taiwanCommon
        }
    }

    /// Presets shown in 開場設定, in display order. `classic` and `taiwanCommon` share one
    /// table, so each region shows only one of them.
    public var rulePresets: [RulePreset] {
        switch self {
        case .hongKong: return [.hongKongDefault, .noMultiplier, .classic]
        case .taiwan: return [.taiwanCommon, .hongKongDefault, .noMultiplier]
        }
    }

    /// Picks the interface for 跟系統.
    ///
    /// Rules, in order:
    /// 1. First preferred language is Chinese tagged HK or MO (e.g. `zh-Hant-HK`, `zh-HK`) → Hong Kong.
    /// 2. First preferred language is Chinese tagged TW (e.g. `zh-Hant-TW`, `zh-TW`) → Taiwan.
    /// 3. Device region is TW → Taiwan.
    /// 4. Otherwise → Hong Kong.
    public static func detect(preferredLanguages: [String], regionCode: String?) -> InterfaceRegion {
        if let first = preferredLanguages.first {
            let parts = first
                .replacingOccurrences(of: "_", with: "-")
                .split(separator: "-")
                .map { $0.uppercased() }
            if parts.first == "ZH" {
                let tags = Set(parts.dropFirst())
                if !tags.isDisjoint(with: ["HK", "MO"]) { return .hongKong }
                if tags.contains("TW") { return .taiwan }
            }
        }
        if regionCode?.uppercased() == "TW" { return .taiwan }
        return .hongKong
    }
}

/// The 地區介面 setting: 跟系統 (default), 香港 or 台灣.
public enum InterfaceRegionPreference: String, Codable, CaseIterable, Sendable {
    case system
    case hongKong
    case taiwan

    public func resolved(systemRegion: InterfaceRegion) -> InterfaceRegion {
        switch self {
        case .system: return systemRegion
        case .hongKong: return .hongKong
        case .taiwan: return .taiwan
        }
    }

    public func title(in region: InterfaceRegion) -> String {
        switch (self, region) {
        case (.system, .hongKong): return "跟系統"
        case (.system, .taiwan): return "跟隨系統"
        case (.hongKong, _): return "香港"
        case (.taiwan, _): return "台灣"
        }
    }
}
