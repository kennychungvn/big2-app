import Foundation
import ScoringEngine

/// Built-in scoring tables shown in 開場設定. Which ones are listed depends on
/// `InterfaceRegion.rulePresets`.
public enum RulePreset: String, Codable, CaseIterable, Sendable {
    /// 1–7 ×1, 8–9 ×2, 10–12 ×3, 13 ×4.
    case hongKongDefault
    /// Every leftover count scores at ×1.
    case noMultiplier
    /// 1–9 ×1, 10–12 ×2, 13 ×3.
    case classic
    /// 台灣常見: 1–9 ×1, 10–12 ×2, 13 ×3 (same table as `classic`, Taiwan label).
    case taiwanCommon

    public var rule: ScoringRule {
        switch self {
        case .hongKongDefault: return .hongKongDefault
        case .noMultiplier: return .noMultiplier
        case .classic: return .classic
        case .taiwanCommon: return .taiwanCommon
        }
    }

    /// Hong Kong wording, kept for existing callers.
    public var displayName: String { displayName(in: .hongKong) }

    /// Hong Kong wording, kept for existing callers.
    public var summary: String { summary(in: .hongKong) }

    public func displayName(in region: InterfaceRegion) -> String {
        switch (self, region) {
        case (.hongKongDefault, .hongKong): return "香港炒"
        case (.hongKongDefault, .taiwan): return "香港算法"
        case (.noMultiplier, .hongKong): return "唔炒"
        case (.noMultiplier, .taiwan): return "不加倍"
        case (.classic, _): return "經典"
        case (.taiwanCommon, _): return "台灣常見"
        }
    }

    public func summary(in region: InterfaceRegion) -> String {
        switch (self, region) {
        case (.hongKongDefault, _):
            return "1-7張 ×1 · 8-9張 ×2 · 10-12張 ×3 · 13張 ×4"
        case (.noMultiplier, .hongKong):
            return "所有剩牌都係 ×1，唔炒倍"
        case (.noMultiplier, .taiwan):
            return "剩幾張算幾分，不加倍"
        case (.classic, _), (.taiwanCommon, _):
            return "1-9張 ×1 · 10-12張 ×2 · 13張 ×3"
        }
    }

    /// The preset to show in `region`'s list: itself if listed, otherwise the preset with the
    /// same table (`classic` ↔ `taiwanCommon`), otherwise the region default.
    public func equivalent(in region: InterfaceRegion) -> RulePreset {
        let available = region.rulePresets
        if available.contains(self) { return self }
        if let twin = available.first(where: { $0.rule.tiers == rule.tiers }) { return twin }
        return region.defaultRulePreset
    }

    /// Hong Kong matching, kept for existing callers.
    public init(matching rule: ScoringRule) {
        self.init(matching: rule, in: .hongKong)
    }

    /// Maps a stored rule back to a preset label. `classic` and `taiwanCommon` share tiers,
    /// so the region decides which name is shown. Unknown tables fall back to the region default.
    public init(matching rule: ScoringRule, in region: InterfaceRegion) {
        if let match = region.rulePresets.first(where: { $0.rule.tiers == rule.tiers }) {
            self = match
        } else if let match = RulePreset.allCases.first(where: { $0.rule.tiers == rule.tiers }) {
            self = match.equivalent(in: region)
        } else {
            self = region.defaultRulePreset
        }
    }
}
