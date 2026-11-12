import Foundation
import ScoringEngine

/// Fixed scoring tables from builds before the 炒法 editor.
///
/// Only kept so `LastSettings` written by those builds (`"rulePreset": "classic"` etc.) still
/// decode; new code uses `ChaoTable`. Saved sessions never stored a preset, they store the full
/// `ScoringRule`, so they are unaffected.
public enum RulePreset: String, Codable, CaseIterable, Sendable {
    case hongKongDefault
    case noMultiplier
    case classic
    case taiwanCommon

    public var rule: ScoringRule {
        switch self {
        case .hongKongDefault: return .hongKongDefault
        case .noMultiplier: return .noMultiplier
        case .classic: return .classic
        case .taiwanCommon: return .taiwanCommon
        }
    }

    /// The editor table with the same multipliers.
    public var chaoTable: ChaoTable { ChaoTable(rule: rule) }
}
