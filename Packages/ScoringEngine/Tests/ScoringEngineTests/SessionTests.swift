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
        var session = try Session(players: names)
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
        var session = try Session(players: names)
        try session.addRound(cardsLeft: [0, 5, 9, 11])
        try session.addRound(cardsLeft: [1, 0, 1, 1])

        let undone = try session.undoLastRound()
        XCTAssertEqual(undone.winnerIndex, 1)
        XCTAssertEqual(session.roundsCompleted, 1)
        XCTAssertEqual(session.totals, [56, -5, -18, -33])
    }

    func testUndoWithNoRoundsThrows() throws {
        var session = try Session(players: names)
        XCTAssertThrowsError(try session.undoLastRound()) { error in
            XCTAssertEqual(error as? ScoringError, .noRoundsToUndo)
        }
    }

    func testEditRoundRecalculatesTotals() throws {
        var session = try Session(players: names)
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
        var session = try Session(players: names)
        try session.addRound(cardsLeft: [0, 1, 1, 1])
        XCTAssertThrowsError(try session.editRound(at: 1, cardsLeft: [0, 2, 2, 2])) { error in
            XCTAssertEqual(error as? ScoringError, .invalidRoundIndex(1))
        }
        XCTAssertThrowsError(try session.editRound(at: -1, cardsLeft: [0, 2, 2, 2])) { error in
            XCTAssertEqual(error as? ScoringError, .invalidRoundIndex(-1))
        }
    }

    func testRankingSortedByTotalDescending() throws {
        var session = try Session(players: names)
        // Kenny +56, Ming -5, Keung -18, May -33
        try session.addRound(cardsLeft: [0, 5, 9, 11])

        let ranking = session.ranking
        XCTAssertEqual(ranking.map(\.name), ["Kenny", "Ming", "Keung", "May"])
        XCTAssertEqual(ranking.map(\.rank), [1, 2, 3, 4])
        XCTAssertEqual(ranking.map(\.total), [56, -5, -18, -33])
        XCTAssertEqual(ranking.map(\.index), [0, 1, 2, 3])
        XCTAssertEqual(ranking.map(\.money), [nil, nil, nil, nil])
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

    func testMoneyTotalsAndRankingMoney() throws {
        var session = try Session(players: names, pointValue: Decimal(string: "0.5")!)
        try session.addRound(cardsLeft: [0, 5, 9, 11])

        XCTAssertEqual(session.moneyTotals, [Decimal(28), Decimal(string: "-2.5")!, Decimal(-9), Decimal(string: "-16.5")!])

        let ranking = session.ranking
        XCTAssertEqual(ranking[0].money, Decimal(28))
        XCTAssertEqual(ranking[1].money, Decimal(string: "-2.5"))
        XCTAssertEqual(ranking[2].money, Decimal(-9))
        XCTAssertEqual(ranking[3].money, Decimal(string: "-16.5"))
    }

    func testMoneyTotalsNilWhenPointValueMissing() throws {
        var session = try Session(players: names)
        try session.addRound(cardsLeft: [0, 1, 1, 1])
        XCTAssertNil(session.moneyTotals)
    }

    func testSessionIsCodable() throws {
        var session = try Session(
            players: names,
            rule: .classic.withDoubleOnHeldTwo(true),
            pointValue: 2
        )
        try session.addRound(cardsLeft: [0, 5, 9, 11], heldTwo: [false, true, false, false])

        let data = try JSONEncoder().encode(session)
        let decoded = try JSONDecoder().decode(Session.self, from: data)
        XCTAssertEqual(decoded, session)
        XCTAssertEqual(decoded.totals, session.totals)
        XCTAssertEqual(decoded.pointValue, 2)
    }

    func testDefaultRuleIsHongKongDefault() throws {
        let session = try Session(players: names)
        XCTAssertEqual(session.rule, .hongKongDefault)
        XCTAssertEqual(session.interstitialMinimumInterval, InterstitialPolicy.defaultMinimumInterval)
    }
}
