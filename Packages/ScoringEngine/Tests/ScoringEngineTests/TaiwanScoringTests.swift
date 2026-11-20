import XCTest
@testable import ScoringEngine

/// 台灣玩法: leftover × card multiplier, then ×2 per manual double; 贏家通吃 or 互對.
final class TaiwanScoringTests: XCTestCase {
    /// 8–9 ×2, 10–12 ×3, 13 ×4 (editable thresholds; this is the Taiwan-app default).
    private let rule = ScoringRule.hongKongDefault

    // MARK: - Penalty helper

    func testCardMultipliersOnDefaultTable() throws {
        for cards in 1...7 {
            XCTAssertEqual(try rule.multiplier(forCardsLeft: cards), 1)
        }
        XCTAssertEqual(try rule.multiplier(forCardsLeft: 8), 2)
        XCTAssertEqual(try rule.multiplier(forCardsLeft: 9), 2)
        XCTAssertEqual(try rule.multiplier(forCardsLeft: 10), 3)
        XCTAssertEqual(try rule.multiplier(forCardsLeft: 11), 3)
        XCTAssertEqual(try rule.multiplier(forCardsLeft: 12), 3)
        XCTAssertEqual(try rule.multiplier(forCardsLeft: 13), 4)
    }

    func testPenaltyTimesTwoPerManualDouble() {
        // 10 cards ×3 with 1 double = 60
        XCTAssertEqual(
            ScoringEngine.penalty(cardsLeft: 10, baseMultiplier: 3, manualDoubles: 1),
            60
        )
        // 13 cards ×4 with 2 doubles = 208
        XCTAssertEqual(
            ScoringEngine.penalty(cardsLeft: 13, baseMultiplier: 4, manualDoubles: 2),
            208
        )
        // 5 cards, no double = 5
        XCTAssertEqual(
            ScoringEngine.penalty(cardsLeft: 5, baseMultiplier: 1, manualDoubles: 0),
            5
        )
        XCTAssertEqual(ScoringEngine.penalty(cardsLeft: 8, baseMultiplier: 2, manualDoubles: 0), 16)
        XCTAssertEqual(ScoringEngine.penalty(cardsLeft: 8, baseMultiplier: 2, manualDoubles: 3), 128)
        XCTAssertEqual(ScoringEngine.penalty(cardsLeft: 0, baseMultiplier: 1, manualDoubles: 4), 0)
    }

    func testManualDoublesAreClamped() {
        XCTAssertEqual(ScoringEngine.clampManualDoubles(-3), 0)
        XCTAssertEqual(ScoringEngine.clampManualDoubles(0), 0)
        XCTAssertEqual(ScoringEngine.clampManualDoubles(8), 8)
        XCTAssertEqual(ScoringEngine.clampManualDoubles(99), ScoringEngine.maxManualDoubles)
        // 13 × 4 × 2^8 = 13_312; does not overflow.
        XCTAssertEqual(
            ScoringEngine.penalty(cardsLeft: 13, baseMultiplier: 4, manualDoubles: 99),
            13 * 4 * 256
        )
    }

    func testHeldTwoAndManualDoublesStack() {
        // HK held-two (one extra ×2) plus a manual double would be ×4 on the tier. The
        // Taiwan app does not use held-two; this only documents the combined formula.
        XCTAssertEqual(
            ScoringEngine.penalty(cardsLeft: 10, baseMultiplier: 3, heldTwoApplied: true, manualDoubles: 1),
            10 * 3 * 2 * 2
        )
    }

    // MARK: - Mockup example (贏家通吃)

    /// Winner, 10×3 with 1 double = 60, 13×4 with 2 doubles = 208, 5 cards = 5, total 273.
    func testWinnerTakesAllMockupExample() throws {
        let round = try ScoringEngine.score(
            cardsLeft: [0, 10, 13, 5],
            rule: rule,
            mode: .winnerTakesAll,
            manualDoubles: [0, 1, 2, 0]
        )

        XCTAssertEqual(round.scores[0].penalty, 0)
        XCTAssertEqual(round.scores[1].penalty, 60)
        XCTAssertEqual(round.scores[1].baseMultiplier, 3)
        XCTAssertEqual(round.scores[1].manualDoubles, 1)
        XCTAssertEqual(round.scores[1].appliedMultiplier, 6)
        XCTAssertFalse(round.scores[1].heldTwoApplied)

        XCTAssertEqual(round.scores[2].penalty, 208)
        XCTAssertEqual(round.scores[2].baseMultiplier, 4)
        XCTAssertEqual(round.scores[2].manualDoubles, 2)
        XCTAssertEqual(round.scores[2].appliedMultiplier, 16)

        XCTAssertEqual(round.scores[3].penalty, 5)
        XCTAssertEqual(round.scores[3].baseMultiplier, 1)
        XCTAssertEqual(round.scores[3].manualDoubles, 0)

        let total = round.scores[1].penalty + round.scores[2].penalty + round.scores[3].penalty
        XCTAssertEqual(total, 273)
        XCTAssertEqual(round.points, [273, -60, -208, -5])
        XCTAssertEqual(round.points.reduce(0, +), 0)
        XCTAssertEqual(round.winnerIndex, 0)
    }

    func testWinnerTakesAllLoserPaysOwnScoreOnly() throws {
        let round = try ScoringEngine.score(
            cardsLeft: [3, 0, 8, 1],
            rule: rule,
            mode: .winnerTakesAll,
            manualDoubles: [0, 0, 1, 0]
        )
        // 3×1=3, winner, 8×2×2=32, 1×1=1; winner collects 36
        XCTAssertEqual(round.points, [-3, 36, -32, -1])
    }

    func testWinnerManualDoublesAreIgnored() throws {
        let round = try ScoringEngine.score(
            cardsLeft: [0, 5, 5, 5],
            rule: rule,
            mode: .winnerTakesAll,
            manualDoubles: [4, 0, 0, 0]
        )
        XCTAssertEqual(round.scores[0].manualDoubles, 0)
        XCTAssertEqual(round.points, [15, -5, -5, -5])
    }

    // MARK: - 互對 (pairwise settlement of computed scores)

    func testPairwiseDifferenceExampleA3VsB16() throws {
        // A 3 cards (p=3) vs B 8×2=16: B pays A 13. The other two are winners/losers
        // chosen so we can also check the four-player net formula.
        // Players: A=3, B=8 no double (16), C=0 winner, D=5 (5). P = 3+16+5 = 24
        // score_i = P − 4 p_i
        // A: 24-12=12, B: 24-64=-40, C: 24-0=24, D: 24-20=4
        // Pair check A vs B: B pays A 13 → A +13, B -13
        // A vs C: A pays C 3 → A -3
        // A vs D: D=5, A pays D 2 → A -2; A net = 13-3-2=8... wait I wanted A 3 vs B 8×2.
        // Recalc A net: 13 (from B) - 3 (to winner) - 2 (to D) = 8, not 12. I mis-set?
        // p_A=3, p_B=16, p_C=0, p_D=5, P=24
        // A vs B: 16-3=13, A+13
        // A vs C: 0-3=-3, A-3
        // A vs D: 5-3=2, A-2  → net 8
        // Formula P-4p = 24-12=12. DISCREPANCY?
        // Wait 4 * p_A = 12, 24-12=12. But pair sum is 8. What's wrong?
        // Oh! There are 3 others, formula is P - 4 p_i because P includes p_i:
        // score_i = Σ_j (p_j - p_i) for j≠i = (P - p_i) - 3 p_i = P - 4 p_i. Yes.
        // Pair A-D: difference is p_D - p_A = 5-3 = +2 for A? "Every pair settles the difference
        // in their computed scores". If A has 3 and D has 5, D pays A? No: the one with the
        // higher computed score (penalty) pays the difference. D (5) pays A (3) the difference 2.
        // So A gets +2 from D, not A pays D.
        // I had the sign backwards for A vs D.
        // A vs B: B 16 pays A 3 the 13. A+13
        // A vs C (winner 0): A pays winner 3. A-3
        // A vs D: D pays A 2. A+2
        // Net A = 13-3+2 = 12. Matches P-4p. Good.
        let round = try ScoringEngine.score(
            cardsLeft: [3, 8, 0, 5],
            rule: rule,
            mode: .pairwise,
            manualDoubles: [0, 0, 0, 0]
        )
        XCTAssertEqual(round.scores[0].penalty, 3)
        XCTAssertEqual(round.scores[1].penalty, 16)
        XCTAssertEqual(round.points[0], 12)
        XCTAssertEqual(round.points[1], 24 - 4 * 16)
        XCTAssertEqual(round.points[2], 24)
        XCTAssertEqual(round.points[3], 24 - 20)
        XCTAssertEqual(round.points.reduce(0, +), 0)
        // Isolated A vs B difference is 13, as in the product brief.
        XCTAssertEqual(round.scores[1].penalty - round.scores[0].penalty, 13)
    }

    func testPairwiseNetIsSumOverOtherThree() throws {
        // Mockup penalties: 0, 60, 208, 5. P=273
        let round = try ScoringEngine.score(
            cardsLeft: [0, 10, 13, 5],
            rule: rule,
            mode: .pairwise,
            manualDoubles: [0, 1, 2, 0]
        )
        XCTAssertEqual(
            [0, 60, 208, 5].reduce(0, +),
            273
        )
        XCTAssertEqual(round.points[0], 273)           // 273 - 0
        XCTAssertEqual(round.points[1], 273 - 4 * 60)  // 33
        XCTAssertEqual(round.points[2], 273 - 4 * 208) // -559
        XCTAssertEqual(round.points[3], 273 - 4 * 5)   // 253
        XCTAssertEqual(round.points, [273, 33, -559, 253])
        XCTAssertEqual(round.points.reduce(0, +), 0)

        // Winner vs 10-card: that loser pays 60 to the winner.
        // Winner vs 13-card: pays 208. Winner vs 5-card: pays 5. Winner net 273.
        // 10-card vs 13-card: 208-60=148 paid to the 10-card player.
        // 10-card vs 5-card: 60-5=55 paid to the 5-card player.
        // 10-card net: -60 (to winner) +148 (from 13) -55 (to 5-card) = 33.
        let p = round.scores.map(\.penalty)
        let tenNet = (p[0] - p[1]) + (p[2] - p[1]) + (p[3] - p[1])
        XCTAssertEqual(tenNet, 33)
        XCTAssertEqual(tenNet, round.points[1])
    }

    func testPairwiseWithoutDoublesStillMatchesLegacyHongKong() throws {
        let legacy = try ScoringEngine.score(
            cardsLeft: [0, 5, 9, 11],
            rule: rule,
            heldTwo: [false, false, false, false],
            mode: .pairwise
        )
        let viaManual = try ScoringEngine.score(
            cardsLeft: [0, 5, 9, 11],
            rule: rule,
            mode: .pairwise,
            manualDoubles: [0, 0, 0, 0]
        )
        XCTAssertEqual(legacy, viaManual)
    }

    func testHongKongHeldTwoUnchangedWhenManualDoublesOmitted() throws {
        let heldTwoRule = rule.withDoubleOnHeldTwo(true)
        let round = try ScoringEngine.score(
            cardsLeft: [0, 5, 9, 11],
            rule: heldTwoRule,
            heldTwo: [false, true, false, false],
            mode: .pairwise
        )
        // 5×1×2=10 when held two; 9×2=18; 11×3=33; P=61
        XCTAssertTrue(round.scores[1].heldTwoApplied)
        XCTAssertEqual(round.scores[1].manualDoubles, 0)
        XCTAssertEqual(round.scores[1].penalty, 10)
        XCTAssertEqual(round.scores[2].penalty, 18)
        XCTAssertEqual(round.scores[3].penalty, 33)
    }

    // MARK: - Codable / session

    func testRoundScoreDecodesMissingManualDoublesAsZero() throws {
        let json = """
        {"cardsLeft":8,"baseMultiplier":2,"heldTwoApplied":false,"points":-16}
        """.data(using: .utf8)!
        let score = try JSONDecoder().decode(RoundScore.self, from: json)
        XCTAssertEqual(score.manualDoubles, 0)
        XCTAssertEqual(score.penalty, 16)
    }

    func testSessionAddRoundPassesManualDoubles() throws {
        var session = try Session(
            players: ["A", "B", "C", "D"],
            rule: rule,
            scoringMode: .winnerTakesAll
        )
        let round = try session.addRound(
            cardsLeft: [0, 10, 13, 5],
            manualDoubles: [0, 1, 2, 0]
        )
        XCTAssertEqual(round.points, [273, -60, -208, -5])
        let edited = try session.editRound(
            at: 0,
            cardsLeft: [0, 10, 13, 5],
            manualDoubles: [0, 0, 0, 0]
        )
        // 10×3=30, 13×4=52, 5=5, total 87
        XCTAssertEqual(edited.points, [87, -30, -52, -5])
    }

    func testManualDoublesWrongCountThrows() {
        XCTAssertThrowsError(
            try ScoringEngine.score(
                cardsLeft: [0, 1, 1, 1],
                rule: rule,
                mode: .winnerTakesAll,
                manualDoubles: [0, 1]
            )
        ) { error in
            guard case ScoringError.wrongPlayerCount = error else {
                return XCTFail("expected wrongPlayerCount, got \(error)")
            }
        }
    }

    func testCustomThresholdsChangeTheBase() throws {
        // 8–13 all ×1, then one double on 10 cards: 10×1×2=20, not 60.
        let flat = try ScoringRule(tiers: [MultiplierTier(minCards: 1, maxCards: 13, multiplier: 1)])
        let round = try ScoringEngine.score(
            cardsLeft: [0, 10, 13, 5],
            rule: flat,
            mode: .winnerTakesAll,
            manualDoubles: [0, 1, 2, 0]
        )
        XCTAssertEqual(round.scores[1].penalty, 20)
        XCTAssertEqual(round.scores[2].penalty, 13 * 1 * 4)
        XCTAssertEqual(round.scores[3].penalty, 5)
        XCTAssertEqual(round.points[0], 20 + 52 + 5)
    }
}
