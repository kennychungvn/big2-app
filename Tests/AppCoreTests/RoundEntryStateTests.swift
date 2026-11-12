import XCTest
import ScoringEngine
@testable import AppCore

final class RoundEntryStateTests: XCTestCase {

    private let names = ["阿明", "Kenny", "阿強", "阿May"]

    private func make(_ rule: ScoringRule = .hongKongDefault) -> RoundEntryState {
        RoundEntryState(rule: rule)
    }

    func testStartsFocusedOnPlayerOneWithPadEnabled() {
        let state = make()
        XCTAssertEqual(state.status, .notStarted)
        XCTAssertEqual(state.focusedIndex, 0)
        XCTAssertNil(state.winnerIndex)
        XCTAssertTrue(state.isPadEnabled)
        XCTAssertTrue(state.canEnterWinner)
        XCTAssertFalse(state.isComplete)
        XCTAssertEqual(state.hintText, "逐個入剩幾多張，出清牌嘅㩒「贏」")
        XCTAssertEqual(state.hintText(in: .taiwan), "依序輸入剩幾張，先出完的點「贏」")
        XCTAssertEqual(state.padPrompt(playerNames: names), "阿明 剩幾多張？")
        XCTAssertEqual(state.padPrompt(playerNames: names, region: .taiwan), "阿明 剩幾張？")
    }

    func testEntriesAdvanceInSeatOrder() {
        var state = make()
        state.enterCards(5)
        XCTAssertEqual(state.cards, [5, nil, nil, nil])
        XCTAssertEqual(state.focusedIndex, 1)
        XCTAssertEqual(state.status, .entering)
        XCTAssertEqual(state.hintText(in: .hongKong), "入完自動跳下一個，㩒邊行都改得")
        XCTAssertEqual(state.hintText(in: .taiwan), "輸入後會自動跳到下一位，點任一列可修改")
        XCTAssertEqual(state.padPrompt(playerNames: names), "Kenny 剩幾多張？")
        state.enterWinner()
        XCTAssertEqual(state.winnerIndex, 1)
        XCTAssertEqual(state.focusedIndex, 2)
        state.enterCards(9)
        XCTAssertEqual(state.focusedIndex, 3)
        XCTAssertFalse(state.isComplete)
        state.enterCards(11)
        XCTAssertTrue(state.isComplete)
        XCTAssertTrue(state.justCompleted)
        XCTAssertNil(state.focusedIndex)
        XCTAssertEqual(state.completeCards, [5, 0, 9, 11])
        XCTAssertEqual(state.status, .complete(cardsLeft: [5, 0, 9, 11]))
        XCTAssertEqual(state.hintText, "入完喇，計緊分…")
    }

    func testWinnerFirstThenLosers() {
        var state = make()
        state.enterWinner()
        XCTAssertEqual(state.cards, [0, nil, nil, nil])
        XCTAssertFalse(state.canEnterWinner, "贏 is disabled for the others")
        state.enterCards(3)
        state.enterCards(8)
        state.enterCards(13)
        XCTAssertEqual(state.completeCards, [0, 3, 8, 13])
    }

    func testSecondWinnerIsIgnored() {
        var state = make()
        state.enterWinner()
        state.enterWinner()  // focused on player 2 now; ignored
        XCTAssertEqual(state.cards, [0, nil, nil, nil])
        XCTAssertEqual(state.focusedIndex, 1)
    }

    func testChangingTheWinnerByRefocusingTheirRow() {
        var state = make()
        state.enterWinner()
        state.enterCards(5)
        state.selectPlayer(0)
        XCTAssertTrue(state.canEnterWinner)
        state.enterCards(7)  // old winner now has cards
        XCTAssertNil(state.winnerIndex)
        XCTAssertEqual(state.cards, [7, 5, nil, nil])
        XCTAssertEqual(state.focusedIndex, 2, "focus moves to the next empty row")
        state.enterWinner()
        XCTAssertEqual(state.winnerIndex, 2)
    }

    func testAllFourFilledWithoutWinnerDoesNotScore() {
        var state = make()
        state.enterCards(1)
        state.enterCards(2)
        state.enterCards(3)
        state.enterCards(4)
        XCTAssertFalse(state.isComplete)
        XCTAssertFalse(state.justCompleted)
        XCTAssertEqual(state.status, .needsWinner)
        XCTAssertEqual(state.hintText, "逐個入剩幾多張，出清牌嘅㩒「贏」")
        XCTAssertEqual(state.focusedIndex, 3, "focus stays on the last row")
        XCTAssertTrue(state.canEnterWinner)
        state.enterWinner()
        XCTAssertTrue(state.justCompleted)
        XCTAssertEqual(state.completeCards, [1, 2, 3, 0])
    }

    func testEnteringLowCardsDoesNotCreateBadge() {
        var state = make()
        state.enterCards(5)
        XCTAssertNil(state.pendingBadge)
        state.enterWinner()
        XCTAssertNil(state.pendingBadge)
    }

    func testBadgesForEachTier() {
        var state = make()
        state.enterCards(8)
        XCTAssertEqual(state.pendingBadge, .init(playerIndex: 0, multiplier: 2, cardsLeft: 8))
        state.enterCards(11)
        XCTAssertEqual(state.pendingBadge?.multiplier, 3)
        state.enterCards(13)
        XCTAssertEqual(state.pendingBadge?.multiplier, 4)
        XCTAssertEqual(state.pendingBadge?.playerIndex, 2)
    }

    func testClassicRuleHasNoTimesFourBadge() {
        var state = make(.classic)
        state.enterCards(13)
        XCTAssertEqual(state.pendingBadge?.multiplier, 3)
        state.enterCards(10)
        XCTAssertEqual(state.pendingBadge?.multiplier, 2)
        state.enterCards(7)
        XCTAssertNil(state.pendingBadge)
    }

    func testNoMultiplierNeverCreatesBadge() {
        var state = make(.noMultiplier)
        state.enterCards(13)
        XCTAssertNil(state.pendingBadge)
    }

    func testInvalidCountsAreIgnored() {
        var state = make()
        state.enterCards(14)
        state.enterCards(-1)
        XCTAssertEqual(state.cards, [nil, nil, nil, nil])
        XCTAssertFalse(state.canUndo)
    }

    func testSelectPlayerLetsYouEditAFilledRow() {
        var state = make()
        state.enterCards(5)
        state.selectPlayer(0)
        state.enterCards(8)
        XCTAssertEqual(state.cards[0], 8)
        XCTAssertEqual(state.pendingBadge?.multiplier, 2)
        XCTAssertEqual(state.focusedIndex, 1)
    }

    func testUndoRestoresPreviousInput() {
        var state = make()
        state.enterCards(8)
        state.enterWinner()
        state.undo()
        XCTAssertEqual(state.cards, [8, nil, nil, nil])
        XCTAssertEqual(state.focusedIndex, 1)
        state.undo()
        XCTAssertEqual(state.status, .notStarted)
        XCTAssertEqual(state.focusedIndex, 0)
        XCTAssertNil(state.pendingBadge)
        XCTAssertFalse(state.canUndo)
        state.undo()  // no-op
        XCTAssertEqual(state.status, .notStarted)
    }

    func testRetappingARowOverwritesIt() {
        var state = make()
        state.enterWinner()
        state.enterCards(5)
        state.enterCards(9)
        state.selectPlayer(1)
        state.enterCards(12)
        XCTAssertEqual(state.cards, [0, 12, 9, nil])
        XCTAssertEqual(state.focusedIndex, 3)
        state.enterCards(2)
        XCTAssertEqual(state.completeCards, [0, 12, 9, 2])
    }

    func testPrefillForEditStartsUnfocusedAndScoresOnChange() {
        var state = RoundEntryState(rule: .hongKongDefault, prefill: [5, 0, 9, 11])
        XCTAssertTrue(state.isComplete)
        XCTAssertFalse(state.justCompleted)
        XCTAssertNil(state.focusedIndex)
        XCTAssertFalse(state.isPadEnabled)
        state.selectPlayer(0)
        state.enterCards(6)
        XCTAssertTrue(state.justCompleted)
        XCTAssertEqual(state.completeCards, [6, 0, 9, 11])
    }

    func testEditCanMoveTheWinner() {
        var state = RoundEntryState(rule: .hongKongDefault, prefill: [5, 0, 9, 11])
        state.selectPlayer(2)
        XCTAssertFalse(state.canEnterWinner)
        state.selectPlayer(1)
        state.enterCards(4)  // old winner now lost with 4
        XCTAssertFalse(state.isComplete)
        state.selectPlayer(0)
        state.enterWinner()
        XCTAssertTrue(state.justCompleted)
        XCTAssertEqual(state.completeCards, [0, 4, 9, 11])
    }

    func testConsumePendingBadgeClearsIt() {
        var state = make()
        state.enterCards(9)
        XCTAssertNotNil(state.consumePendingBadge())
        XCTAssertNil(state.pendingBadge)
    }

    /// Every 炒倍 gets the same plain badge (no 炒到盡 / 最高 wording).
    func testBadgeIsPlainMultiplier() {
        var hk = make(.hongKongDefault)
        hk.enterCards(13)
        XCTAssertEqual(hk.consumePendingBadge(), .init(playerIndex: 0, multiplier: 4, cardsLeft: 13))
        hk.enterCards(12)
        XCTAssertEqual(hk.consumePendingBadge(), .init(playerIndex: 1, multiplier: 3, cardsLeft: 12))
    }
}
