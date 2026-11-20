import XCTest
import ScoringEngine
@testable import AppCore

final class TaiwanAppCoreTests: XCTestCase {
    func testDaLaoErDefaultMatchesApprovedThresholds() {
        let table = ChaoTable.daLaoErDefault
        for cards in 1...7 { XCTAssertEqual(table.multiplier(forCards: cards), 1) }
        XCTAssertEqual(table.multiplier(forCards: 8), 2)
        XCTAssertEqual(table.multiplier(forCards: 9), 2)
        XCTAssertEqual(table.multiplier(forCards: 10), 3)
        XCTAssertEqual(table.multiplier(forCards: 12), 3)
        XCTAssertEqual(table.multiplier(forCards: 13), 4)
        // Must not silently reuse the milder 台灣常見 table from the HK app's TW toggle.
        XCTAssertNotEqual(ChaoTable.daLaoErDefault, ChaoTable.taiwanDefault)
        XCTAssertEqual(ChaoTable.daLaoErDefault, ChaoTable.hongKongDefault)
    }

    func testLastSettingsDecodesMissingScoringModeAsNil() throws {
        let json = """
        {"playerNames":["A","B","C","D"],"chaoTable":{"multipliers":[2,2,3,3,3,4]}}
        """.data(using: .utf8)!
        let settings = try JSONDecoder().decode(LastSettings.self, from: json)
        XCTAssertNil(settings.scoringMode)
        XCTAssertEqual(settings.chaoTable, .hongKongDefault)
    }

    func testLastSettingsRoundTripsScoringMode() throws {
        let original = LastSettings(
            playerNames: ["小明", "阿強", "小美", "志明"],
            chaoTable: .daLaoErDefault,
            scoringMode: .pairwise
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(LastSettings.self, from: data)
        XCTAssertEqual(decoded.scoringMode, .pairwise)
        XCTAssertEqual(decoded.chaoTable, .daLaoErDefault)
    }

    func testNewSessionDraftHongKongPathStillDefaultsPairwiseAndHKTable() {
        // `swift test` compiles AppCore without TAIWAN, so this is the HK app path.
        let draft = NewSessionDraft()
        XCTAssertEqual(AppFlavor.current, .hongKong)
        XCTAssertEqual(draft.scoringMode, .pairwise)
        XCTAssertEqual(draft.chaoTable, .hongKongDefault)
    }

    func testPenaltyFormulaShowsEachDouble() {
        let format = ScoreFormatting(region: .taiwan)
        XCTAssertEqual(
            format.penaltyFormula(cardsLeft: 10, baseMultiplier: 3, manualDoubles: 1),
            "10 張 ×3 ×2 = 60"
        )
        XCTAssertEqual(
            format.penaltyFormula(cardsLeft: 13, baseMultiplier: 4, manualDoubles: 2),
            "13 張 ×4 ×2 ×2 = 208"
        )
        XCTAssertEqual(
            format.penaltyFormula(cardsLeft: 5, baseMultiplier: 1, manualDoubles: 0),
            "5 張 ×1 = 5"
        )
        XCTAssertEqual(format.penaltyFormula(cardsLeft: 0, baseMultiplier: 1, manualDoubles: 2), "贏")
    }

    func testRoundDetailShowsManualDoublesWithoutHeldTwoWording() throws {
        let round = try ScoringEngine.score(
            cardsLeft: [0, 10, 13, 5],
            rule: .hongKongDefault,
            mode: .winnerTakesAll,
            manualDoubles: [0, 1, 2, 0]
        )
        let displays = RoundPresentation.displays(from: round)
        let format = ScoreFormatting(region: .taiwan)
        XCTAssertEqual(format.roundDetail(score: displays[0]), "出完")
        XCTAssertEqual(format.roundDetail(score: displays[1]), "10 張 ×3 ×2")
        XCTAssertEqual(format.roundDetail(score: displays[2]), "13 張 ×4 ×2 ×2")
        XCTAssertEqual(format.roundDetail(score: displays[3]), "5 張 ×1")
        XCTAssertFalse(format.roundDetail(score: displays[1]).contains("炒"))
        XCTAssertFalse(format.roundDetail(score: displays[1]).contains("有 2"))
    }

    func testRoundEntryRequiresConfirmAndDoublesStepper() {
        var state = RoundEntryState(rule: .hongKongDefault, requiresConfirm: true)
        state.enterWinner() // player 0
        state.enterCards(10)
        state.enterCards(13)
        state.enterCards(5)
        XCTAssertTrue(state.isComplete)
        XCTAssertFalse(state.justCompleted)
        XCTAssertTrue(state.canConfirm)
        XCTAssertEqual(state.livePenalty(at: 1), 30) // 10×3, no double yet
        state.incrementDoubles(at: 1)
        XCTAssertEqual(state.livePenalty(at: 1), 60)
        state.incrementDoubles(at: 2)
        state.incrementDoubles(at: 2)
        XCTAssertEqual(state.livePenalty(at: 2), 208)
        XCTAssertEqual(state.livePenalty(at: 3), 5)
        XCTAssertEqual(state.liveWinnerTakesAllTotal, 273)
        // Winner cannot take doubles.
        state.incrementDoubles(at: 0)
        XCTAssertEqual(state.manualDoubles[0], 0)
        state.confirm()
        XCTAssertTrue(state.justCompleted)
        XCTAssertEqual(state.completeCards, [0, 10, 13, 5])
        XCTAssertEqual(state.completeManualDoubles, [0, 1, 2, 0])
    }

    func testRoundEntryDoublesUndoAndPrefill() {
        var state = RoundEntryState(
            rule: .hongKongDefault,
            prefill: [0, 10, 13, 5],
            prefillManualDoubles: [0, 1, 2, 0],
            requiresConfirm: true
        )
        XCTAssertEqual(state.manualDoubles, [0, 1, 2, 0])
        XCTAssertEqual(state.liveWinnerTakesAllTotal, 273)
        state.selectPlayer(1)
        state.decrementDoubles(at: 1)
        XCTAssertEqual(state.livePenalty(at: 1), 30)
        state.undo()
        XCTAssertEqual(state.manualDoubles[1], 1)
        // Changing the winner row clears its doubles (already 0) and a loser row stays.
        state.selectPlayer(0)
        state.enterCards(4) // no longer winner; needs a new winner
        XCTAssertFalse(state.isComplete)
        state.selectPlayer(1)
        state.enterWinner()
        XCTAssertEqual(state.manualDoubles[1], 0)
    }

    func testHongKongEntryStillAutoCompletesWithoutDoubles() {
        var state = RoundEntryState(rule: .hongKongDefault)
        XCTAssertFalse(state.requiresConfirm)
        state.enterWinner()
        state.enterCards(5)
        state.enterCards(9)
        state.enterCards(11)
        XCTAssertTrue(state.justCompleted)
        XCTAssertEqual(state.completeManualDoubles, [0, 0, 0, 0])
    }

    func testAppModelPersistsManualDoublesAndScoringMode() throws {
        var model = AppModel()
        _ = try model.startNewSession(
            players: ["小明", "阿強", "小美", "志明"],
            chaoTable: .daLaoErDefault,
            scoringMode: .winnerTakesAll
        )
        XCTAssertEqual(model.data.lastSettings.scoringMode, .winnerTakesAll)
        let round = try model.addRound(cardsLeft: [0, 10, 13, 5], manualDoubles: [0, 1, 2, 0])
        XCTAssertEqual(round.points, [273, -60, -208, -5])
        XCTAssertEqual(model.currentSession?.session.scoringMode, .winnerTakesAll)
    }

    func testPairwiseBreakdownOmitsZhangSuffixWhenAsked() throws {
        let round = try ScoringEngine.score(
            cardsLeft: [3, 8, 0, 5],
            rule: .hongKongDefault,
            mode: .pairwise
        )
        let items = RoundPresentation.pairwiseBreakdown(from: round)
        let format = ScoreFormatting(region: .taiwan)
        let line = format.pairwiseBreakdown(items[0], names: ["A", "B", "C", "D"], unitSuffix: "")
        XCTAssertFalse(line.contains("張"))
        XCTAssertTrue(line.contains("贏") || line.contains("輸"))
        // HK default still uses 張.
        let hk = ScoreFormatting().pairwiseBreakdown(items[0], names: ["A", "B", "C", "D"])
        XCTAssertTrue(hk.contains("張"))
    }

    func testAppFlavorResolvePrefersPlistAndBundleId() {
        XCTAssertEqual(AppFlavor.resolve(compilationFlagTaiwan: true, plistFlavor: nil, bundleIdentifier: "com.kenny.daidee"), .taiwan)
        XCTAssertEqual(AppFlavor.resolve(compilationFlagTaiwan: false, plistFlavor: "taiwan", bundleIdentifier: "com.kenny.daidee"), .taiwan)
        XCTAssertEqual(AppFlavor.resolve(compilationFlagTaiwan: false, plistFlavor: nil, bundleIdentifier: "com.kenny.dalaoer"), .taiwan)
        XCTAssertEqual(AppFlavor.resolve(compilationFlagTaiwan: false, plistFlavor: "hongkong", bundleIdentifier: "com.kenny.dalaoer"), .hongKong)
        XCTAssertEqual(AppFlavor.resolve(compilationFlagTaiwan: false, plistFlavor: nil, bundleIdentifier: "com.kenny.daidee"), .hongKong)
        XCTAssertEqual(AppFlavor.resolve(compilationFlagTaiwan: false, plistFlavor: "TODO", bundleIdentifier: "com.kenny.daidee"), .hongKong)
        // Package tests (no plist, not the Taiwan bundle) stay on the Hong Kong flavor.
        XCTAssertEqual(AppFlavor.current, .hongKong)
    }
}
