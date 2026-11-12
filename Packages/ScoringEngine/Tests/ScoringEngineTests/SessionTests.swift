import XCTest
import Foundation
@testable import ScoringEngine

final class SessionTests: XCTestCase {

    private let names = ["Kenny", "Ming", "Keung", "May"]

    func testSessionRequiresFourPlayers() {
        XCTAssertThrowsError(try Session(players: ["A", "B", "C"])) { error in
            XCTAssertEqual(error as? ScoringError, .wrongPlayerCount(expected: 4, actual: 3))
        }
    }

    func testAddRoundUpdatesTotalsAndRoundsCompleted() throws {
        var session = try Session(players: names, scoringMode: .winnerTakesAll)
        XCTAssertEqual(session.roundsCompleted, 0)
        XCTAssertEqual(session.totals, [0, 0, 0, 0])

        try session.addRound(cardsLeft: [0, 5, 9, 11])
        XCTAssertEqual(session.roundsCompleted, 1)
        XCTAssertEqual(session.totals, [56, -5, -18, -33])

        try session.addRound(cardsLeft: [7, 0, 1, 1])
        XCTAssertEqual(session.roundsCompleted, 2)
        XCTAssertEqual(session.totals, [56 - 7, -5 + 9, -18 - 1, -33 - 1])
    }

    func testUndoLastRound() throws {
        var session = try Session(players: names, scoringMode: .winnerTakesAll)
        try session.addRound(cardsLeft: [0, 5, 9, 11])
        try session.addRound(cardsLeft: [1, 0, 1, 1])

        let undone = try session.undoLastRound()
        XCTAssertEqual(undone.winnerIndex, 1)
        XCTAssertEqual(session.roundsCompleted, 1)
        XCTAssertEqual(session.totals, [56, -5, -18, -33])
    }

    func testUndoWithNoRoundsThrows() throws {
        var session = try Session(players: names, scoringMode: .winnerTakesAll)
        XCTAssertThrowsError(try session.undoLastRound()) { error in
            XCTAssertEqual(error as? ScoringError, .noRoundsToUndo)
        }
    }

    func testEditRoundRecalculatesTotals() throws {
        var session = try Session(players: names, scoringMode: .winnerTakesAll)
        try session.addRound(cardsLeft: [0, 5, 9, 11])
        try session.addRound(cardsLeft: [1, 0, 1, 1])

        let edited = try session.editRound(at: 0, cardsLeft: [13, 13, 0, 13])
        // 13 cards under hongKongDefault is ×4 → 52 each, winner +156
        XCTAssertEqual(edited.points, [-52, -52, 156, -52])
        XCTAssertEqual(session.roundsCompleted, 2)
        // Round 0 replaced; round 1 still [ -1, 3, -1, -1 ]
        XCTAssertEqual(session.totals, [-52 - 1, -52 + 3, 156 - 1, -52 - 1])
    }

    func testEditInvalidIndexThrows() throws {
        var session = try Session(players: names, scoringMode: .winnerTakesAll)
        try session.addRound(cardsLeft: [0, 1, 1, 1])
        XCTAssertThrowsError(try session.editRound(at: 1, cardsLeft: [0, 2, 2, 2])) { error in
            XCTAssertEqual(error as? ScoringError, .invalidRoundIndex(1))
        }
        XCTAssertThrowsError(try session.editRound(at: -1, cardsLeft: [0, 2, 2, 2])) { error in
            XCTAssertEqual(error as? ScoringError, .invalidRoundIndex(-1))
        }
    }

    func testRankingSortedByTotalDescending() throws {
        var session = try Session(players: names, scoringMode: .winnerTakesAll)
        // Kenny +56, Ming -5, Keung -18, May -33
        try session.addRound(cardsLeft: [0, 5, 9, 11])

        let ranking = session.ranking
        XCTAssertEqual(ranking.map(\.name), ["Kenny", "Ming", "Keung", "May"])
        XCTAssertEqual(ranking.map(\.rank), [1, 2, 3, 4])
        XCTAssertEqual(ranking.map(\.total), [56, -5, -18, -33])
        XCTAssertEqual(ranking.map(\.index), [0, 1, 2, 3])
    }

    func testRankingUsesCompetitionRankForTies() throws {
        var session = try Session(players: names, rule: .noMultiplier)
        // After this: Kenny +3, Ming -1, Keung -1, May -1
        try session.addRound(cardsLeft: [0, 1, 1, 1])

        let ranking = session.ranking
        XCTAssertEqual(ranking.map(\.index), [0, 1, 2, 3])
        XCTAssertEqual(ranking.map(\.rank), [1, 2, 2, 2])
        XCTAssertEqual(ranking.map(\.total), [3, -1, -1, -1])
    }

    func testRankingBreaksTotalTiesByPlayerIndex() throws {
        var session = try Session(players: names, rule: .noMultiplier)
        // May +3, others -1 each. May should be first; losers 0,1,2 stay in index order.
        try session.addRound(cardsLeft: [1, 1, 1, 0])

        let ranking = session.ranking
        XCTAssertEqual(ranking.map(\.index), [3, 0, 1, 2])
        XCTAssertEqual(ranking.map(\.name), ["May", "Kenny", "Ming", "Keung"])
        XCTAssertEqual(ranking.map(\.rank), [1, 2, 2, 2])
    }

    func testLegacySessionJSONWithPointValueStillDecodes() throws {
        var session = try Session(players: names, scoringMode: .winnerTakesAll)
        try session.addRound(cardsLeft: [0, 5, 9, 11])
        var object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(session)) as! [String: Any]
        object["pointValue"] = 2  // field written by builds before 每分幾錢 was removed
        object.removeValue(forKey: "scoringMode")  // builds before pairwise scoring
        let legacy = try JSONSerialization.data(withJSONObject: object)
        let decoded = try JSONDecoder().decode(Session.self, from: legacy)
        XCTAssertEqual(decoded, session)
        XCTAssertEqual(decoded.scoringMode, .winnerTakesAll, "old saves keep the mode they were scored with")
        XCTAssertEqual(decoded.totals, [56, -5, -18, -33])
    }

    func testSessionIsCodable() throws {
        var session = try Session(
            players: names,
            rule: .classic.withDoubleOnHeldTwo(true)
        )
        try session.addRound(cardsLeft: [0, 5, 9, 11], heldTwo: [false, true, false, false])

        let data = try JSONEncoder().encode(session)
        let decoded = try JSONDecoder().decode(Session.self, from: data)
        XCTAssertEqual(decoded, session)
        XCTAssertEqual(decoded.totals, session.totals)
    }

    func testDefaultRuleIsHongKongDefault() throws {
        let session = try Session(players: names, scoringMode: .winnerTakesAll)
        XCTAssertEqual(session.rule, .hongKongDefault)
        XCTAssertEqual(session.interstitialMinimumInterval, InterstitialPolicy.defaultMinimumInterval)
    }
}
