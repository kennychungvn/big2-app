import XCTest
import ScoringEngine
@testable import AppCore

final class RoundEntryStateTests: XCTestCase {

    private func make(_ rule: ScoringRule = .hongKongDefault) -> RoundEntryState {
        RoundEntryState(rule: rule)
    }

    func testStartsByPickingWinnerWithPadDisabled() {
        let state = make()
        XCTAssertEqual(state.status, .pickingWinner)
        XCTAssertNil(state.winnerIndex)
        XCTAssertFalse(state.isPadEnabled)
        XCTAssertFalse(state.isComplete)
        XCTAssertEqual(state.hintText, "㩒「贏」揀邊個出清牌")
        XCTAssertEqual(state.padPrompt(playerNames: ["阿明", "Kenny", "阿強", "阿May"]), "先揀贏家")
    }

    func testMarkWinnerSetsZeroAndFocusesNextLoser() {
        var state = make()
        state.markWinner(1)
        XCTAssertEqual(state.cards, [nil, 0, nil, nil])
        XCTAssertEqual(state.winnerIndex, 1)
        XCTAssertEqual(state.focusedIndex, 2)
        XCTAssertEqual(state.status, .enteringLosers)
        XCTAssertTrue(state.isPadEnabled)
    }

    func testWinnerAtLastSeatWrapsFocusToFirst() {
        var state = make()
        state.markWinner(3)
        XCTAssertEqual(state.focusedIndex, 0)
    }

    func testTappingCurrentWinnerUnsetsThem() {
        var state = make()
        state.markWinner(1)
        state.markWinner(1)
        XCTAssertNil(state.winnerIndex)
        XCTAssertEqual(state.status, .pickingWinner)
        XCTAssertEqual(state.cards, [nil, nil, nil, nil])
    }

    func testChangingWinnerClearsThePreviousOne() {
        var state = make()
        state.markWinner(0)
        state.enterCards(5)
        state.markWinner(2)
        XCTAssertEqual(state.winnerIndex, 2)
        XCTAssertEqual(state.cards[0], nil)
        XCTAssertEqual(state.cards[2], 0)
    }

    func testEnterCardsBeforeWinnerIsIgnored() {
        var state = make()
        state.selectPlayer(0)
        state.enterCards(5)
        XCTAssertEqual(state.cards, [nil, nil, nil, nil])
        XCTAssertFalse(state.justCompleted)
    }

    func testEnteringLowCardsDoesNotCreateBadge() {
        var state = make()
        state.markWinner(0)
        state.enterCards(5)
        XCTAssertNil(state.pendingBadge)
        XCTAssertEqual(state.cards[1], 5)
        XCTAssertEqual(state.focusedIndex, 2)
    }

    func testEnteringTierTwoCreatesBadge() {
        var state = make()
        state.markWinner(0)
        state.enterCards(8)
        XCTAssertEqual(state.pendingBadge?.playerIndex, 1)
        XCTAssertEqual(state.pendingBadge?.multiplier, 2)
        XCTAssertEqual(state.pendingBadge?.cardsLeft, 8)
    }

    func testEnteringTierThreeAndFourCreatesBadge() {
        var state = make()
        state.markWinner(0)
        state.enterCards(11)
        XCTAssertEqual(state.pendingBadge?.multiplier, 3)
        state.enterCards(13)
        XCTAssertEqual(state.pendingBadge?.multiplier, 4)
        XCTAssertEqual(state.pendingBadge?.playerIndex, 2)
    }

    func testClassicRuleHasNoTimesFourBadge() {
        var state = make(.classic)
        state.markWinner(0)
        state.enterCards(13)
        XCTAssertEqual(state.pendingBadge?.multiplier, 3)
        state.selectPlayer(2)
        state.enterCards(10)
        XCTAssertEqual(state.pendingBadge?.multiplier, 2)
        state.selectPlayer(3)
        state.enterCards(7)
        XCTAssertNil(state.pendingBadge)
    }

    func testNoMultiplierNeverCreatesBadge() {
        var state = make(.noMultiplier)
        state.markWinner(0)
        state.enterCards(13)
        XCTAssertNil(state.pendingBadge)
    }

    func testLastLoserAutoCompletes() {
        var state = make()
        // players: 0 阿明, 1 Kenny, 2 阿強, 3 阿May
        state.markWinner(1) // Kenny
        XCTAssertEqual(state.focusedIndex, 2)
        state.enterCards(9) // 阿強
        XCTAssertEqual(state.focusedIndex, 3)
        state.enterCards(11) // 阿May
        XCTAssertEqual(state.focusedIndex, 0)
        XCTAssertFalse(state.isComplete)
        state.enterCards(5) // 阿明
        XCTAssertTrue(state.isComplete)
        XCTAssertTrue(state.justCompleted)
        XCTAssertEqual(state.completeCards, [5, 0, 9, 11])
        XCTAssertNil(state.focusedIndex)
        if case .complete(let cards) = state.status {
            XCTAssertEqual(cards, [5, 0, 9, 11])
        } else {
            XCTFail("expected complete")
        }
    }

    func testSelectPlayerLetsYouEditAFilledRow() {
        var state = make()
        state.markWinner(0)
        state.enterCards(5)
        state.selectPlayer(1)
        state.enterCards(8)
        XCTAssertEqual(state.cards[1], 8)
        XCTAssertEqual(state.pendingBadge?.multiplier, 2)
    }

    func testUndoRestoresPreviousInput() {
        var state = make()
        state.markWinner(0)
        state.enterCards(8)
        XCTAssertEqual(state.cards[1], 8)
        state.undo()
        XCTAssertEqual(state.cards[1], nil)
        XCTAssertEqual(state.focusedIndex, 1)
        XCTAssertNil(state.pendingBadge)
        state.undo()
        XCTAssertEqual(state.status, .pickingWinner)
        XCTAssertFalse(state.canUndo)
        state.undo() // no-op
        XCTAssertEqual(state.status, .pickingWinner)
    }

    func testClearFocusedClearsOnlyThatRow() {
        var state = make()
        state.markWinner(0)
        state.enterCards(5)
        state.selectPlayer(1)
        state.clearFocusedOrAll()
        XCTAssertEqual(state.cards, [0, nil, nil, nil])
        XCTAssertEqual(state.winnerIndex, 0)
    }

    func testClearAllResetsToPickingWinner() {
        var state = make()
        state.markWinner(0)
        state.enterCards(5)
        state.clearAll()
        XCTAssertEqual(state.status, .pickingWinner)
        XCTAssertEqual(state.cards, [nil, nil, nil, nil])
        state.undo()
        XCTAssertEqual(state.winnerIndex, 0)
        XCTAssertEqual(state.cards[1], 5)
    }

    func testPrefillForEditDoesNotAutoCompleteUntilAChange() {
        var state = RoundEntryState(rule: .hongKongDefault, prefill: [5, 0, 9, 11])
        XCTAssertTrue(state.isComplete)
        XCTAssertFalse(state.justCompleted)
        XCTAssertEqual(state.completeCards, [5, 0, 9, 11])
        state.selectPlayer(0)
        state.enterCards(6)
        XCTAssertTrue(state.justCompleted)
        XCTAssertEqual(state.completeCards, [6, 0, 9, 11])
    }

    func testConsumePendingBadgeClearsIt() {
        var state = make()
        state.markWinner(0)
        state.enterCards(9)
        XCTAssertNotNil(state.consumePendingBadge())
        XCTAssertNil(state.pendingBadge)
    }

    func testPadPromptUsesFocusedName() {
        var state = make()
        state.markWinner(1)
        XCTAssertEqual(
            state.padPrompt(playerNames: ["阿明", "Kenny", "阿強", "阿May"]),
            "阿強 剩幾多張？"
        )
    }

    func testCannotEnterCardsOnTheWinnerRow() {
        var state = make()
        state.markWinner(0)
        state.selectPlayer(0)
        XCTAssertFalse(state.isPadEnabled)
        state.enterCards(7)
        XCTAssertEqual(state.cards[0], 0)
    }
}
