import Foundation
import ScoringEngine

/// The 炒法 picked in 開場設定: 1–7 leftover cards always score ×1, and each of 8–13 cards
/// has its own multiplier from ×1 to ×4.
///
/// Any combination is allowed, including non-monotonic ones (e.g. 12張 ×3 but 13張 ×2);
/// that is the players' house rule to choose.
public struct ChaoTable: Codable, Equatable, Hashable, Sendable {
    /// Card counts that have an editable tile.
    public static let editableCounts: ClosedRange<Int> = 8...13
    public static let multiplierRange: ClosedRange<Int> = 1...4

    /// Multipliers for 8, 9, 10, 11, 12, 13 cards, in that order. Always six values in 1...4.
    public private(set) var multipliers: [Int]

    /// - Parameter multipliers: Values for 8...13 cards. Missing values become ×1, extra values
    ///   are dropped, and each value is clamped to 1...4.
    public init(multipliers: [Int]) {
        var values = Array(multipliers.prefix(Self.editableCounts.count))
        while values.count < Self.editableCounts.count { values.append(1) }
        self.multipliers = values.map { Self.clamp($0) }
    }

    /// Reads the 8–13 card multipliers out of any stored rule (1–7 are not editable here).
    public init(rule: ScoringRule) {
        self.init(multipliers: Self.editableCounts.map { (try? rule.multiplier(forCardsLeft: $0)) ?? 1 })
    }

    /// 香港炒: 8-9 ×2, 10-12 ×3, 13 ×4.
    public static let hongKongDefault = ChaoTable(multipliers: [2, 2, 3, 3, 3, 4])
    /// 台灣常見: 8-9 ×1, 10-12 ×2, 13 ×3.
    public static let taiwanDefault = ChaoTable(multipliers: [1, 1, 2, 2, 2, 3])
    /// 唔炒 / 不加倍: every count ×1.
    public static let noMultiplier = ChaoTable(multipliers: [1, 1, 1, 1, 1, 1])

    public func multiplier(forCards cards: Int) -> Int {
        guard Self.editableCounts.contains(cards) else { return 1 }
        return multipliers[cards - Self.editableCounts.lowerBound]
    }

    /// Tapping a tile: ×1 → ×2 → ×3 → ×4 → ×1. Counts outside 8...13 are ignored.
    public mutating func cycle(cards: Int) {
        guard Self.editableCounts.contains(cards) else { return }
        let index = cards - Self.editableCounts.lowerBound
        let next = multipliers[index] + 1
        multipliers[index] = next > Self.multiplierRange.upperBound ? Self.multiplierRange.lowerBound : next
    }

    public func cycled(cards: Int) -> ChaoTable {
        var copy = self
        copy.cycle(cards: cards)
        return copy
    }

    /// Engine rule with equal neighbouring counts merged into one tier.
    public var rule: ScoringRule {
        let perCount = (1...13).map { multiplier(forCards: $0) }
        let tiers = ChaoTable.groups(perCount).map {
            MultiplierTier(minCards: $0.min, maxCards: $0.max, multiplier: $0.multiplier)
        }
        // Tiers built here always cover 1...13 with multipliers ≥ 1, so validation cannot fail.
        return (try? ScoringRule(tiers: tiers)) ?? .noMultiplier
    }

    private enum CodingKeys: String, CodingKey { case multipliers }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(multipliers: try container.decode([Int].self, forKey: .multipliers))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(multipliers, forKey: .multipliers)
    }

    private static func clamp(_ value: Int) -> Int {
        min(max(value, multiplierRange.lowerBound), multiplierRange.upperBound)
    }

    /// Groups consecutive equal values of `perCount` (index 0 = 1 card).
    static func groups(_ perCount: [Int]) -> [(min: Int, max: Int, multiplier: Int)] {
        var result: [(min: Int, max: Int, multiplier: Int)] = []
        for (offset, value) in perCount.enumerated() {
            let cards = offset + 1
            if let last = result.last, last.multiplier == value, last.max == cards - 1 {
                result[result.count - 1].max = cards
            } else {
                result.append((cards, cards, value))
            }
        }
        return result
    }
}

extension ScoreFormatting {
    /// Compact 炒法 line, e.g. `8-9張×2 · 10-12張×3 · 13張×4`. ×1 ranges are left out;
    /// a rule that is ×1 everywhere reads 唔炒 (HK) / 不加倍 (TW). A rule that doubles on a
    /// held 2 gets `· 有 2 再 ×2`.
    public func ruleSummary(_ rule: ScoringRule) -> String {
        let perCount = (1...13).map { (try? rule.multiplier(forCardsLeft: $0)) ?? 1 }
        let parts = ChaoTable.groups(perCount)
            .filter { $0.multiplier != 1 }
            .map { group -> String in
                let range = group.min == group.max ? "\(group.min)" : "\(group.min)-\(group.max)"
                return "\(range)張×\(group.multiplier)"
            }
        var text = parts.isEmpty ? (region == .taiwan ? "不加倍" : "唔炒") : parts.joined(separator: " · ")
        if rule.doubleOnHeldTwo {
            text += " · 有 2 再 ×2"
        }
        return text
    }

    public func ruleSummary(_ table: ChaoTable) -> String {
        ruleSummary(table.rule)
    }
}
