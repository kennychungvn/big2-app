import XCTest
@testable import ScoringEngine

final class ScoringRuleTests: XCTestCase {

    /// Boundaries required by the brief: 1, 7, 8, 9, 10, 12, 13.
    private let boundaries = [1, 7, 8, 9, 10, 12, 13]

    func testHongKongDefaultMultipliersAtEveryBoundary() throws {
        let expected = [1: 1, 7: 1, 8: 2, 9: 2, 10: 3, 12: 3, 13: 4]
        for cards in boundaries {
            let multiplier = try ScoringRule.hongKongDefault.multiplier(forCardsLeft: cards)
            XCTAssertEqual(multiplier, expected[cards], "hongKongDefault failed for \(cards) cards")
        }
        // Also confirm full coverage just outside the named boundaries.
        XCTAssertEqual(try ScoringRule.hongKongDefault.multiplier(forCardsLeft: 6), 1)
        XCTAssertEqual(try ScoringRule.hongKongDefault.multiplier(forCardsLeft: 11), 3)
    }

    func testNoMultiplierIsAlwaysOneAtEveryBoundary() throws {
        for cards in boundaries {
            XCTAssertEqual(
                try ScoringRule.noMultiplier.multiplier(forCardsLeft: cards),
                1,
                "noMultiplier failed for \(cards) cards"
            )
        }
        for cards in 1...13 {
            XCTAssertEqual(try ScoringRule.noMultiplier.multiplier(forCardsLeft: cards), 1)
        }
    }

    func testClassicMultipliersAtEveryBoundary() throws {
        let expected = [1: 1, 7: 1, 8: 1, 9: 1, 10: 2, 12: 2, 13: 3]
        for cards in boundaries {
            let multiplier = try ScoringRule.classic.multiplier(forCardsLeft: cards)
            XCTAssertEqual(multiplier, expected[cards], "classic failed for \(cards) cards")
        }
    }

    func testBoundaryMultipliersAffectScoredPenalties() throws {
        // One loser holds the boundary count; the other two hold 1 card (×1 on every preset).
        let cases: [(ScoringRule, Int, Int)] = [
            (.hongKongDefault, 1, 1),
            (.hongKongDefault, 7, 7),
            (.hongKongDefault, 8, 16),
            (.hongKongDefault, 9, 18),
            (.hongKongDefault, 10, 30),
            (.hongKongDefault, 12, 36),
            (.hongKongDefault, 13, 52),
            (.noMultiplier, 1, 1),
            (.noMultiplier, 7, 7),
            (.noMultiplier, 8, 8),
            (.noMultiplier, 9, 9),
            (.noMultiplier, 10, 10),
            (.noMultiplier, 12, 12),
            (.noMultiplier, 13, 13),
            (.classic, 1, 1),
            (.classic, 7, 7),
            (.classic, 8, 8),
            (.classic, 9, 9),
            (.classic, 10, 20),
            (.classic, 12, 24),
            (.classic, 13, 39)
        ]

        for (rule, cards, expectedPenalty) in cases {
            let round = try ScoringEngine.score(cardsLeft: [0, cards, 1, 1], rule: rule)
            XCTAssertEqual(
                round.points[1],
                -expectedPenalty,
                "Penalty mismatch for \(cards) cards"
            )
            XCTAssertEqual(round.points[0], expectedPenalty + 1 + 1)
            XCTAssertEqual(round.points.reduce(0, +), 0)
        }
    }

    func testCustomRuleValidationAcceptsContiguousCoverage() throws {
        let rule = try ScoringRule(tiers: [
            MultiplierTier(minCards: 1, maxCards: 4, multiplier: 1),
            MultiplierTier(minCards: 5, maxCards: 13, multiplier: 2)
        ])
        XCTAssertEqual(try rule.multiplier(forCardsLeft: 4), 1)
        XCTAssertEqual(try rule.multiplier(forCardsLeft: 5), 2)
        XCTAssertEqual(try rule.multiplier(forCardsLeft: 13), 2)
    }

    func testCustomRuleNormalizesTierOrder() throws {
        let rule = try ScoringRule(tiers: [
            MultiplierTier(minCards: 10, maxCards: 13, multiplier: 3),
            MultiplierTier(minCards: 1, maxCards: 9, multiplier: 1)
        ])
        XCTAssertEqual(rule.tiers.first?.minCards, 1)
        XCTAssertEqual(try rule.multiplier(forCardsLeft: 10), 3)
    }

    func testCustomRuleRejectsEmptyTiers() {
        XCTAssertThrowsError(try ScoringRule(tiers: [])) { error in
            XCTAssertEqual(error as? RuleValidationError, .emptyTiers)
        }
    }

    func testCustomRuleRejectsInvalidCardRange() {
        XCTAssertThrowsError(
            try ScoringRule(tiers: [MultiplierTier(minCards: 5, maxCards: 3, multiplier: 1)])
        ) { error in
            XCTAssertEqual(
                error as? RuleValidationError,
                .invalidCardRange(minCards: 5, maxCards: 3)
            )
        }
        XCTAssertThrowsError(
            try ScoringRule(tiers: [MultiplierTier(minCards: 0, maxCards: 13, multiplier: 1)])
        ) { error in
            XCTAssertEqual(
                error as? RuleValidationError,
                .invalidCardRange(minCards: 0, maxCards: 13)
            )
        }
        XCTAssertThrowsError(
            try ScoringRule(tiers: [MultiplierTier(minCards: 1, maxCards: 14, multiplier: 1)])
        ) { error in
            XCTAssertEqual(
                error as? RuleValidationError,
                .invalidCardRange(minCards: 1, maxCards: 14)
            )
        }
    }

    func testCustomRuleRejectsMultiplierBelowOne() {
        XCTAssertThrowsError(
            try ScoringRule(tiers: [MultiplierTier(minCards: 1, maxCards: 13, multiplier: 0)])
        ) { error in
            XCTAssertEqual(error as? RuleValidationError, .multiplierMustBeAtLeastOne(0))
        }
        XCTAssertThrowsError(
            try ScoringRule(tiers: [MultiplierTier(minCards: 1, maxCards: 13, multiplier: -2)])
        ) { error in
            XCTAssertEqual(error as? RuleValidationError, .multiplierMustBeAtLeastOne(-2))
        }
    }

    func testCustomRuleRejectsIncompleteCoverage() {
        XCTAssertThrowsError(
            try ScoringRule(tiers: [MultiplierTier(minCards: 2, maxCards: 13, multiplier: 1)])
        ) { error in
            XCTAssertEqual(error as? RuleValidationError, .doesNotCoverOneToThirteen)
        }
        XCTAssertThrowsError(
            try ScoringRule(tiers: [MultiplierTier(minCards: 1, maxCards: 12, multiplier: 1)])
        ) { error in
            XCTAssertEqual(error as? RuleValidationError, .doesNotCoverOneToThirteen)
        }
    }

    func testCustomRuleRejectsOverlappingTiers() {
        XCTAssertThrowsError(
            try ScoringRule(tiers: [
                MultiplierTier(minCards: 1, maxCards: 8, multiplier: 1),
                MultiplierTier(minCards: 8, maxCards: 13, multiplier: 2)
            ])
        ) { error in
            XCTAssertEqual(error as? RuleValidationError, .overlappingTiers)
        }
    }

    func testCustomRuleRejectsGaps() {
        XCTAssertThrowsError(
            try ScoringRule(tiers: [
                MultiplierTier(minCards: 1, maxCards: 7, multiplier: 1),
                MultiplierTier(minCards: 9, maxCards: 13, multiplier: 2)
            ])
        ) { error in
            XCTAssertEqual(error as? RuleValidationError, .gapInCoverage(missingCard: 8))
        }
    }

    func testPresetsHaveHeldTwoOffByDefault() {
        XCTAssertFalse(ScoringRule.hongKongDefault.doubleOnHeldTwo)
        XCTAssertFalse(ScoringRule.noMultiplier.doubleOnHeldTwo)
        XCTAssertFalse(ScoringRule.classic.doubleOnHeldTwo)
    }

    func testRuleIsCodable() throws {
        let rule = ScoringRule.hongKongDefault.withDoubleOnHeldTwo(true)
        let data = try JSONEncoder().encode(rule)
        let decoded = try JSONDecoder().decode(ScoringRule.self, from: data)
        XCTAssertEqual(decoded, rule)
        XCTAssertTrue(decoded.doubleOnHeldTwo)
    }

    func testDecodingRejectsInvalidRule() throws {
        let json = """
        {"tiers":[{"minCards":1,"maxCards":7,"multiplier":1}],"doubleOnHeldTwo":false}
        """.data(using: .utf8)!
        XCTAssertThrowsError(try JSONDecoder().decode(ScoringRule.self, from: json))
    }
}
