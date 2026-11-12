/// A contiguous range of leftover card counts that share one multiplier.
public struct MultiplierTier: Codable, Equatable, Hashable, Sendable {
    public let minCards: Int
    public let maxCards: Int
    public let multiplier: Int

    public init(minCards: Int, maxCards: Int, multiplier: Int) {
        self.minCards = minCards
        self.maxCards = maxCards
        self.multiplier = multiplier
    }
}

/// Configurable leftover-card multiplier table, plus the optional 大Dee (held 2) toggle.
///
/// Tiers must cover card counts 1 through 13 contiguously, with no gaps or overlaps,
/// and every multiplier must be at least 1.
public struct ScoringRule: Codable, Equatable, Sendable {
    public let tiers: [MultiplierTier]
    /// When true, a loser who held any 2 has their penalty doubled.
    public let doubleOnHeldTwo: Bool

    /// App default: 1–7 ×1, 8–9 ×2, 10–12 ×3, 13 ×4.
    public static let hongKongDefault = ScoringRule(
        validatedTiers: [
            MultiplierTier(minCards: 1, maxCards: 7, multiplier: 1),
            MultiplierTier(minCards: 8, maxCards: 9, multiplier: 2),
            MultiplierTier(minCards: 10, maxCards: 12, multiplier: 3),
            MultiplierTier(minCards: 13, maxCards: 13, multiplier: 4)
        ],
        doubleOnHeldTwo: false
    )

    /// Every leftover card count scores at ×1.
    public static let noMultiplier = ScoringRule(
        validatedTiers: [
            MultiplierTier(minCards: 1, maxCards: 13, multiplier: 1)
        ],
        doubleOnHeldTwo: false
    )

    /// Classic table: 1–9 ×1, 10–12 ×2, 13 ×3.
    public static let classic = ScoringRule(
        validatedTiers: [
            MultiplierTier(minCards: 1, maxCards: 9, multiplier: 1),
            MultiplierTier(minCards: 10, maxCards: 12, multiplier: 2),
            MultiplierTier(minCards: 13, maxCards: 13, multiplier: 3)
        ],
        doubleOnHeldTwo: false
    )

    /// Creates a rule from a custom tier list. Validates coverage of 1...13.
    public init(tiers: [MultiplierTier], doubleOnHeldTwo: Bool = false) throws {
        let normalized = try Self.validate(tiers: tiers)
        self.init(validatedTiers: normalized, doubleOnHeldTwo: doubleOnHeldTwo)
    }

    private init(validatedTiers: [MultiplierTier], doubleOnHeldTwo: Bool) {
        self.tiers = validatedTiers
        self.doubleOnHeldTwo = doubleOnHeldTwo
    }

    /// Returns a copy of this rule with the held-two toggle changed.
    public func withDoubleOnHeldTwo(_ enabled: Bool) -> ScoringRule {
        ScoringRule(validatedTiers: tiers, doubleOnHeldTwo: enabled)
    }

    /// Multiplier for a loser holding `cardsLeft` cards (not including the held-two extra).
    public func multiplier(forCardsLeft cardsLeft: Int) throws -> Int {
        guard let tier = tiers.first(where: { $0.minCards...$0.maxCards ~= cardsLeft }) else {
            throw ScoringError.cardsOutOfRange(playerIndex: -1, cardsLeft: cardsLeft)
        }
        return tier.multiplier
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedTiers = try container.decode([MultiplierTier].self, forKey: .tiers)
        let decodedDouble = try container.decode(Bool.self, forKey: .doubleOnHeldTwo)
        try self.init(tiers: decodedTiers, doubleOnHeldTwo: decodedDouble)
    }

    private enum CodingKeys: String, CodingKey {
        case tiers
        case doubleOnHeldTwo
    }

    private static func validate(tiers: [MultiplierTier]) throws -> [MultiplierTier] {
        guard !tiers.isEmpty else { throw RuleValidationError.emptyTiers }

        for tier in tiers {
            let rangeIsValid = (1...13).contains(tier.minCards)
                && (1...13).contains(tier.maxCards)
                && tier.minCards <= tier.maxCards
            if !rangeIsValid {
                throw RuleValidationError.invalidCardRange(
                    minCards: tier.minCards,
                    maxCards: tier.maxCards
                )
            }
            if tier.multiplier < 1 {
                throw RuleValidationError.multiplierMustBeAtLeastOne(tier.multiplier)
            }
        }

        let sorted = tiers.sorted { $0.minCards < $1.minCards }
        if sorted[0].minCards != 1 || sorted[sorted.count - 1].maxCards != 13 {
            throw RuleValidationError.doesNotCoverOneToThirteen
        }

        for index in 0..<(sorted.count - 1) {
            let current = sorted[index]
            let next = sorted[index + 1]
            if next.minCards <= current.maxCards {
                throw RuleValidationError.overlappingTiers
            }
            if next.minCards != current.maxCards + 1 {
                throw RuleValidationError.gapInCoverage(missingCard: current.maxCards + 1)
            }
        }

        return sorted
    }
}
