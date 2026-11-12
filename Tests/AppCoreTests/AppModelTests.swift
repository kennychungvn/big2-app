import XCTest
import ScoringEngine
@testable import AppCore

final class AppModelTests: XCTestCase {

    private let names = ["阿明", "Kenny", "阿強", "阿May"]
    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    private func model(clock: MutableClock? = nil) throws -> (AppModel, MutableClock) {
        let clock = clock ?? MutableClock(start)
        var model = AppModel()
        _ = try model.startNewSession(
            players: names,
            preset: .hongKongDefault,
            clock: clock
        )
        return (model, clock)
    }

    func testStartNewSessionTrimsNamesAndRemembersSettings() throws {
        var model = AppModel()
        let clock = MutableClock(start)
        let stored = try model.startNewSession(
            players: [" 阿明 ", "Kenny", "阿強", "阿May"],
            preset: .classic,
            clock: clock
        )
        XCTAssertEqual(stored.session.players, names)
        XCTAssertEqual(stored.session.rule, .classic)
        XCTAssertEqual(model.currentSessionID, stored.id)
        XCTAssertEqual(model.data.lastSettings.playerNames, names)
        XCTAssertEqual(model.data.lastSettings.rulePreset, .classic)
        XCTAssertEqual(model.data.knownPlayerNames, ["阿明", "Kenny", "阿強", "阿May"])
        XCTAssertEqual(model.latestUnfinished?.id, stored.id)
    }

    func testEmptyNameIsRejected() {
        var model = AppModel()
        XCTAssertThrowsError(
            try model.startNewSession(players: ["阿明", "", "阿強", "阿May"], preset: .hongKongDefault)
        ) { error in
            XCTAssertEqual(error as? AppModelError, .emptyPlayerName(index: 1))
        }
    }

    func testAddRoundMatchesWireframeExample() throws {
        var (model, _) = try model()
        let round = try model.addRound(cardsLeft: [5, 0, 9, 11])
        XCTAssertEqual(round.points, [-5, 56, -18, -33])
        XCTAssertEqual(model.currentSession?.session.totals, [-5, 56, -18, -33])
        XCTAssertEqual(model.currentSession?.session.ranking.first?.name, "Kenny")
    }

    func testUndoAndEditRound() throws {
        var (model, _) = try model()
        try model.addRound(cardsLeft: [5, 0, 9, 11])
        try model.addRound(cardsLeft: [0, 3, 4, 5])
        XCTAssertEqual(model.currentSession?.session.roundsCompleted, 2)
        _ = try model.undoLastRound()
        XCTAssertEqual(model.currentSession?.session.roundsCompleted, 1)
        _ = try model.editRound(at: 0, cardsLeft: [0, 1, 1, 1])
        XCTAssertEqual(model.currentSession?.session.totals, [3, -1, -1, -1])
    }

    func testFinishMovesSessionOutOfContinueButton() throws {
        var (model, clock) = try model()
        try model.addRound(cardsLeft: [0, 1, 1, 1], clock: clock)
        XCTAssertNotNil(model.latestUnfinished)
        clock.advance(by: 60)
        try model.finishCurrentSession(clock: clock)
        XCTAssertNil(model.latestUnfinished)
        XCTAssertTrue(model.currentSession?.isFinished == true)
        XCTAssertEqual(model.recentSessions.first?.endedAt, clock.now)
    }

    func testContinueUnfinishedOpensLatest() throws {
        var model = AppModel()
        let clock = MutableClock(start)
        let first = try model.startNewSession(players: names, preset: .hongKongDefault, clock: clock)
        clock.advance(by: 10)
        let second = try model.startNewSession(players: ["A", "B", "C", "D"], preset: .noMultiplier, clock: clock)
        model.closeCurrentSession()
        XCTAssertEqual(model.latestUnfinished?.id, second.id)
        let opened = try model.continueUnfinished()
        XCTAssertEqual(opened.id, second.id)
        XCTAssertEqual(model.currentSessionID, second.id)
        XCTAssertEqual(first.isFinished, false)
    }

    func testKnownNamesMostRecentFirstAndDeduped() throws {
        var model = AppModel()
        let clock = MutableClock(start)
        _ = try model.startNewSession(players: names, preset: .hongKongDefault, clock: clock)
        clock.advance(by: 1)
        _ = try model.startNewSession(
            players: ["阿May", "細佬", "Kenny", "Ben"],
            preset: .hongKongDefault,
            clock: clock
        )
        XCTAssertEqual(model.data.knownPlayerNames, ["阿May", "細佬", "Kenny", "Ben", "阿明", "阿強"])
    }

    func testNameChipsSkipAlreadyFilledFields() throws {
        let (model, _) = try model()
        let chips = model.availableNameChips(for: ["阿明", "", "Kenny", ""])
        XCTAssertFalse(chips.contains("阿明"))
        XCTAssertFalse(chips.contains("Kenny"))
        XCTAssertTrue(chips.contains("阿強"))
        XCTAssertTrue(chips.contains("阿May"))
    }

    func testInterstitialAfterEveryFiveRoundsRespectsAdsRemoved() throws {
        var (model, clock) = try model()
        XCTAssertFalse(model.shouldShowInterstitial(clock: clock))
        for _ in 0..<4 {
            try model.addRound(cardsLeft: [0, 1, 1, 1], clock: clock)
            XCTAssertFalse(model.shouldShowInterstitial(clock: clock))
        }
        try model.addRound(cardsLeft: [0, 1, 1, 1], clock: clock)
        XCTAssertTrue(model.shouldShowInterstitial(clock: clock))

        model.setAdsRemoved(true)
        XCTAssertFalse(model.shouldShowInterstitial(clock: clock))
        model.setAdsRemoved(false)
        XCTAssertTrue(model.shouldShowInterstitial(clock: clock))

        model.recordInterstitialShown(clock: clock)
        XCTAssertFalse(model.shouldShowInterstitial(clock: clock))

        for _ in 0..<5 {
            try model.addRound(cardsLeft: [0, 1, 1, 1], clock: clock)
        }
        clock.advance(by: 179)
        XCTAssertFalse(model.shouldShowInterstitial(clock: clock))
        clock.advance(by: 1)
        XCTAssertTrue(model.shouldShowInterstitial(clock: clock))
    }

    func testHistoryRowsAreNewestFirst() throws {
        var (model, _) = try model()
        try model.addRound(cardsLeft: [0, 1, 1, 1])
        try model.addRound(cardsLeft: [1, 0, 1, 1])
        let rows = model.historyRows()
        XCTAssertEqual(rows.map(\.roundNumber), [2, 1])
        XCTAssertEqual(rows.map(\.index), [1, 0])
    }
}
