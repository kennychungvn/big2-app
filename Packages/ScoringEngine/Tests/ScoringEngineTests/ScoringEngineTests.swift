import XCTest
import Foundation
@testable import ScoringEngine

final class ScoringEngineTests: XCTestCase {

    // MARK: - Example round

    func testHongKongDefaultExampleRound_losers5_9_11() throws {
        // Winner, then losers with 5, 9, and 11 cards.
        let round = try ScoringEngine.score(
            cardsLeft: [0, 5, 9, 11],
            rule: .hongKongDefault
        )

        XCTAssertEqual(round.points, [56, -5, -18, -33])
        XCTAssertEqual(round.scores[1].cardsLeft, 5)
        XCTAssertEqual(round.scores[1].baseMultiplier, 1)
        XCTAssertEqual(round.scores[2].cardsLeft, 9)
        XCTAssertEqual(round.scores[2].baseMultiplier, 2)
        XCTAssertEqual(round.scores[3].cardsLeft, 11)
        XCTAssertEqual(round.scores[3].baseMultiplier, 3)
        XCTAssertEqual(round.winnerIndex, 0)
        XCTAssertEqual(round.points.reduce(0, +), 0)
    }

    func testWinnerInAnySeatReceivesTheSum() throws {
        let round = try ScoringEngine.score(
            cardsLeft: [5, 9, 0, 11],
            rule: .hongKongDefault
        )
        XCTAssertEqual(round.points, [-5, -18, 56, -33])
        XCTAssertEqual(round.winnerIndex, 2)
    }

    // MARK: - Zero sum

    func testRoundScoresAlwaysSumToZero() throws {
        let hands: [[Int]] = [
            [0, 1, 1, 1],
            [0, 7, 8, 9],
            [0, 10, 12, 13],
            [13, 13, 13, 0],
            [1, 0, 12, 8],
            [6, 6, 6, 0]
        ]
        let rules: [ScoringRule] = [
            .hongKongDefault,
            .noMultiplier,
            .classic,
            .hongKongDefault.withDoubleOnHeldTwo(true)
        ]

        for rule in rules {
            for cardsLeft in hands {
                let withoutTwos = try ScoringEngine.score(cardsLeft: cardsLeft, rule: rule)
                XCTAssertEqual(withoutTwos.points.reduce(0, +), 0, "Failed for \(cardsLeft) under \(ruleLabel(rule))")

                let withTwos = try ScoringEngine.score(
                    cardsLeft: cardsLeft,
                    rule: rule,
                    heldTwo: [true, true, true, true]
                )
                XCTAssertEqual(withTwos.points.reduce(0, +), 0)
            }
        }
    }

    // MARK: - Input validation

    func testNoWinner() {
        XCTAssertThrowsError(
            try ScoringEngine.score(cardsLeft: [1, 2, 3, 4], rule: .hongKongDefault)
        ) { error in
            XCTAssertEqual(error as? ScoringError, .noWinner)
        }
    }

    func testMultipleWinners() {
        XCTAssertThrowsError(
            try ScoringEngine.score(cardsLeft: [0, 0, 3, 4], rule: .hongKongDefault)
        ) { error in
            XCTAssertEqual(error as? ScoringError, .multipleWinners)
        }
    }

    func testCardsOutOfRange() {
        XCTAssertThrowsError(
            try ScoringEngine.score(cardsLeft: [0, 14, 3, 4], rule: .hongKongDefault)
        ) { error in
            XCTAssertEqual(error as? ScoringError, .cardsOutOfRange(playerIndex: 1, cardsLeft: 14))
        }
        XCTAssertThrowsError(
            try ScoringEngine.score(cardsLeft: [0, 1, -1, 4], rule: .hongKongDefault)
        ) { error in
            XCTAssertEqual(error as? ScoringError, .cardsOutOfRange(playerIndex: 2, cardsLeft: -1))
        }
    }

    func testWrongPlayerCount() {
        XCTAssertThrowsError(
            try ScoringEngine.score(cardsLeft: [0, 1, 2], rule: .hongKongDefault)
        ) { error in
            XCTAssertEqual(error as? ScoringError, .wrongPlayerCount(expected: 4, actual: 3))
        }
        XCTAssertThrowsError(
            try ScoringEngine.score(
                cardsLeft: [0, 1, 2, 3],
                rule: .hongKongDefault,
                heldTwo: [false, true]
            )
        ) { error in
            XCTAssertEqual(error as? ScoringError, .wrongPlayerCount(expected: 4, actual: 2))
        }
    }

    // MARK: - Held two (大Dee)

    func testHeldTwoIgnoredWhenRuleToggleIsOff() throws {
        let round = try ScoringEngine.score(
            cardsLeft: [0, 5, 9, 11],
            rule: .hongKongDefault, // toggle off
            heldTwo: [false, true, true, true]
        )
        XCTAssertEqual(round.points, [56, -5, -18, -33])
        XCTAssertFalse(round.scores[1].heldTwoApplied)
        XCTAssertFalse(round.scores[2].heldTwoApplied)
        XCTAssertFalse(round.scores[3].heldTwoApplied)
    }

    func testHeldTwoDoublesLoserPenaltyWhenRuleToggleIsOn() throws {
        let rule = ScoringRule.hongKongDefault.withDoubleOnHeldTwo(true)
        // Only the 9-card loser held a 2: 9 × 2 × 2 = 36
        let round = try ScoringEngine.score(
            cardsLeft: [0, 5, 9, 11],
            rule: rule,
            heldTwo: [false, false, true, false]
        )
        XCTAssertEqual(round.points, [5 + 36 + 33, -5, -36, -33])
        XCTAssertEqual(round.points.reduce(0, +), 0)
        XCTAssertFalse(round.scores[1].heldTwoApplied)
        XCTAssertTrue(round.scores[2].heldTwoApplied)
        XCTAssertEqual(round.scores[2].appliedMultiplier, 4)
        XCTAssertFalse(round.scores[3].heldTwoApplied)
    }

    func testHeldTwoDoesNotApplyToPlayersWhoDidNotHoldATwo() throws {
        let rule = ScoringRule.hongKongDefault.withDoubleOnHeldTwo(true)
        let round = try ScoringEngine.score(
            cardsLeft: [0, 5, 9, 11],
            rule: rule,
            heldTwo: [false, false, false, false]
        )
        XCTAssertEqual(round.points, [56, -5, -18, -33])
    }

    func testHeldTwoFlagOnWinnerIsIgnored() throws {
        let rule = ScoringRule.hongKongDefault.withDoubleOnHeldTwo(true)
        let round = try ScoringEngine.score(
            cardsLeft: [0, 5, 9, 11],
            rule: rule,
            heldTwo: [true, false, false, false]
        )
        XCTAssertEqual(round.points, [56, -5, -18, -33])
        XCTAssertFalse(round.scores[0].heldTwoApplied)
    }

    // MARK: - Money

    func testMoneyConversion() {
        XCTAssertEqual(ScoringEngine.money(fromPoints: 56, pointValue: 1), Decimal(56))
        XCTAssertEqual(ScoringEngine.money(fromPoints: 56, pointValue: Decimal(string: "0.5")!), Decimal(28))
        XCTAssertEqual(ScoringEngine.money(fromPoints: -18, pointValue: 2), Decimal(-36))
        XCTAssertEqual(ScoringEngine.money(fromPoints: 0, pointValue: 10), 0)
    }

    // MARK: - Codable

    func testRoundIsCodable() throws {
        let round = try ScoringEngine.score(cardsLeft: [0, 5, 9, 11], rule: .hongKongDefault)
        let data = try JSONEncoder().encode(round)
        let decoded = try JSONDecoder().decode(Round.self, from: data)
        XCTAssertEqual(decoded, round)
    }
}

private func ruleLabel(_ rule: ScoringRule) -> String {
    if rule == .hongKongDefault { return "hongKongDefault" }
    if rule == .noMultiplier { return "noMultiplier" }
    if rule == .classic { return "classic" }
    return "custom"
}
