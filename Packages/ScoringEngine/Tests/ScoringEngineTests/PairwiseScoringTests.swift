import XCTest
@testable import ScoringEngine

extension ScoringEngine {
    /// Test helper for tests about multiplier / penalty math, which read most easily as
    /// winner-takes-all (losers score −penalty).
    static func scoreWinnerTakesAll(cardsLeft: [Int], rule: ScoringRule, heldTwo: [Bool]? = nil) throws -> Round {
        try score(cardsLeft: cardsLeft, rule: rule, heldTwo: heldTwo, mode: .winnerTakesAll)
    }
}

final class PairwiseScoringTests: XCTestCase {

    /// Kenny's example: 香港炒, cards 0 / 11 / 13 / 3 → penalties 0 / 33 / 52 / 3.
    func testHongKongPairwiseExample() throws {
        let round = try ScoringEngine.score(cardsLeft: [0, 11, 13, 3], rule: .hongKongDefault, mode: .pairwise)
        XCTAssertEqual(round.scores.map(\.penalty), [0, 33, 52, 3])
        XCTAssertEqual(round.points, [88, -44, -120, 76])
        XCTAssertEqual(round.points.reduce(0, +), 0)
    }

    func testPairwiseIsTheDefault() throws {
        let round = try ScoringEngine.score(cardsLeft: [0, 11, 13, 3], rule: .hongKongDefault)
        XCTAssertEqual(round.points, [88, -44, -120, 76])
        let session = try Session(players: ["A", "B", "C", "D"])
        XCTAssertEqual(session.scoringMode, .pairwise)
    }

    func testPairwiseMatchesTheSumOfPairDifferences() throws {
        let cases: [[Int]] = [[0, 5, 9, 11], [13, 0, 2, 9], [1, 2, 3, 0], [12, 13, 0, 8]]
        for cards in cases {
            let round = try ScoringEngine.score(cardsLeft: cards, rule: .hongKongDefault, mode: .pairwise)
            let p = round.scores.map(\.penalty)
            for i in 0..<4 {
                let expected = (0..<4).filter { $0 != i }.reduce(0) { $0 + (p[$1] - p[i]) }
                XCTAssertEqual(round.points[i], expected, "\(cards) player \(i)")
            }
            XCTAssertEqual(round.points.reduce(0, +), 0)
        }
    }

    func testPairwiseUsesHeldTwoPenalty() throws {
        let rule = ScoringRule.hongKongDefault.withDoubleOnHeldTwo(true)
        let round = try ScoringEngine.score(
            cardsLeft: [0, 5, 9, 11],
            rule: rule,
            heldTwo: [false, true, false, false],
            mode: .pairwise
        )
        // penalties 0 / 10 / 18 / 33, P = 61
        XCTAssertEqual(round.scores.map(\.penalty), [0, 10, 18, 33])
        XCTAssertEqual(round.points, [61, 21, -11, -71])
    }

    func testWinnerTakesAllStillAvailable() throws {
        let round = try ScoringEngine.score(cardsLeft: [0, 11, 13, 3], rule: .hongKongDefault, mode: .winnerTakesAll)
        XCTAssertEqual(round.points, [88, -33, -52, -3])
    }

    func testSessionScoresWithItsModeIncludingEdits() throws {
        var hk = try Session(players: ["A", "B", "C", "D"], scoringMode: .pairwise)
        try hk.addRound(cardsLeft: [0, 11, 13, 3])
        XCTAssertEqual(hk.totals, [88, -44, -120, 76])
        try hk.editRound(at: 0, cardsLeft: [11, 0, 13, 3])
        XCTAssertEqual(hk.totals, [-44, 88, -120, 76])

        var tw = try Session(players: ["A", "B", "C", "D"], rule: .taiwanCommon, scoringMode: .winnerTakesAll)
        try tw.addRound(cardsLeft: [0, 11, 13, 3])
        XCTAssertEqual(tw.totals, [64, -22, -39, -3])
    }

    func testModeRoundTripsThroughCodable() throws {
        var session = try Session(players: ["A", "B", "C", "D"], scoringMode: .pairwise)
        try session.addRound(cardsLeft: [0, 11, 13, 3])
        let decoded = try JSONDecoder().decode(Session.self, from: JSONEncoder().encode(session))
        XCTAssertEqual(decoded.scoringMode, .pairwise)
        XCTAssertEqual(decoded, session)
    }
}
