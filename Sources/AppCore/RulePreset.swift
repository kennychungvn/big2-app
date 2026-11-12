import Foundation
import ScoringEngine

/// The three built-in scoring tables shown in 開場設定.
public enum RulePreset: String, Codable, CaseIterable, Sendable {
    /// 1–7 ×1, 8–9 ×2, 10–12 ×3, 13 ×4.
    case hongKongDefault
    /// Every leftover count scores at ×1.
    case noMultiplier
    /// 1–9 ×1, 10–12 ×2, 13 ×3.
    case classic

    public var rule: ScoringRule {
        switch self {
        case .hongKongDefault: return .hongKongDefault
        case .noMultiplier: return .noMultiplier
        case .classic: return .classic
        }
    }

    public var displayName: String {
        switch self {
        case .hongKongDefault: return "香港炒"
        case .noMultiplier: return "唔炒"
        case .classic: return "經典"
        }
    }

    public var summary: String {
        switch self {
        case .hongKongDefault:
            return "1-7張 ×1 · 8-9張 ×2 · 10-12張 ×3 · 13張 ×4"
        case .noMultiplier:
            return "所有剩牌都係 ×1，唔炒倍"
        case .classic:
            return "1-9張 ×1 · 10-12張 ×2 · 13張 ×3"
        }
    }

    public init(matching rule: ScoringRule) {
        if rule.tiers == ScoringRule.hongKongDefault.tiers {
            self = .hongKongDefault
        } else if rule.tiers == ScoringRule.noMultiplier.tiers {
            self = .noMultiplier
        } else if rule.tiers == ScoringRule.classic.tiers {
            self = .classic
        } else {
            self = .hongKongDefault
        }
    }
}
