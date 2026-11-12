import XCTest
import ScoringEngine
@testable import AppCore

final class ChaoTableTests: XCTestCase {

    func testTileCyclesOneToFourAndWraps() {
        var table = ChaoTable.noMultiplier
        var seen: [Int] = []
        for _ in 0..<5 {
            table.cycle(cards: 8)
            seen.append(table.multiplier(forCards: 8))
        }
        XCTAssertEqual(seen, [2, 3, 4, 1, 2])
        XCTAssertEqual(table.multiplier(forCards: 9), 1, "other tiles untouched")

        var draft = NewSessionDraft(from: LastSettings(chaoTable: .hongKongDefault))
        draft.cycleMultiplier(cards: 13)
        XCTAssertEqual(draft.chaoTable.multiplier(forCards: 13), 1)
        draft.cycleMultiplier(cards: 13)
        XCTAssertEqual(draft.chaoTable.multiplier(forCards: 13), 2)
    }

    func testOneToSevenAreFixedAtTimesOne() {
        var table = ChaoTable.hongKongDefault
        table.cycle(cards: 7)
        table.cycle(cards: 14)
        XCTAssertEqual(table, .hongKongDefault)
        for cards in 1...7 {
            XCTAssertEqual(table.multiplier(forCards: cards), 1)
        }
    }

    func testInitClampsAndPads() {
        XCTAssertEqual(ChaoTable(multipliers: [0, 9]).multipliers, [1, 4, 1, 1, 1, 1])
        XCTAssertEqual(ChaoTable(multipliers: [2, 2, 2, 2, 2, 2, 2, 2]).multipliers.count, 6)
        let decoded = try? JSONDecoder().decode(ChaoTable.self, from: Data(#"{"multipliers":[7,-1]}"#.utf8))
        XCTAssertEqual(decoded?.multipliers, [4, 1, 1, 1, 1, 1])
    }

    func testRuleMergesEqualNeighbours() {
        XCTAssertEqual(ChaoTable.hongKongDefault.rule, .hongKongDefault)
        XCTAssertEqual(ChaoTable.taiwanDefault.rule, .taiwanCommon)
        XCTAssertEqual(ChaoTable.noMultiplier.rule, .noMultiplier)
        XCTAssertEqual(ChaoTable(rule: .hongKongDefault), .hongKongDefault)
    }

    func testNonMonotonicChoiceIsAllowedAndScores() throws {
        let table = ChaoTable(multipliers: [3, 1, 1, 1, 4, 2])
        let rule = table.rule
        XCTAssertEqual(try rule.multiplier(forCardsLeft: 8), 3)
        XCTAssertEqual(try rule.multiplier(forCardsLeft: 11), 1)
        XCTAssertEqual(try rule.multiplier(forCardsLeft: 12), 4)
        XCTAssertEqual(try rule.multiplier(forCardsLeft: 13), 2)
        var model = AppModel()
        _ = try model.startNewSession(players: ["A", "B", "C", "D"], chaoTable: table)
        let round = try model.addRound(cardsLeft: [0, 8, 12, 13])
        // penalties 0 / 24 / 48 / 26, P = 98, pairwise → 98 − 4p
        XCTAssertEqual(round.points, [98, 2, -94, -6])
    }

    func testSummaryGroupsEqualConsecutiveMultipliers() throws {
        let hk = ScoreFormatting(region: .hongKong)
        let tw = ScoreFormatting(region: .taiwan)
        XCTAssertEqual(hk.ruleSummary(ScoringRule.hongKongDefault), "8-9張×2 · 10-12張×3 · 13張×4")
        XCTAssertEqual(tw.ruleSummary(ChaoTable.taiwanDefault), "10-12張×2 · 13張×3")
        XCTAssertEqual(hk.ruleSummary(ChaoTable.noMultiplier), "唔炒")
        XCTAssertEqual(tw.ruleSummary(ChaoTable.noMultiplier), "不加倍")
        XCTAssertEqual(hk.ruleSummary(ChaoTable(multipliers: [2, 1, 2, 2, 1, 4])), "8張×2 · 10-11張×2 · 13張×4")
        XCTAssertEqual(hk.ruleSummary(ScoringRule.hongKongDefault.withDoubleOnHeldTwo(true)), "8-9張×2 · 10-12張×3 · 13張×4 · 有 2 再 ×2")
        let oldCustom = try ScoringRule(tiers: [
            MultiplierTier(minCards: 1, maxCards: 4, multiplier: 1),
            MultiplierTier(minCards: 5, maxCards: 13, multiplier: 5)
        ])
        XCTAssertEqual(hk.ruleSummary(oldCustom), "5-13張×5")
    }

    func testShareSummaryUsesCompactRuleLine() throws {
        var session = try Session(players: ["阿明", "Kenny", "阿強", "阿May"])
        try session.addRound(cardsLeft: [5, 0, 9, 11])
        let stored = StoredSession(session: session, createdAt: Date(timeIntervalSince1970: 1_700_000_000))
        let summary = ShareSummary(stored: stored)
        XCTAssertEqual(summary.ruleLine, "8-9張×2 · 10-12張×3 · 13張×4")
        XCTAssertTrue(summary.text.contains("2023/11/15"))
    }

    // MARK: - Home lists

    func testHomeRecentCapsAtNineAndSkipsContinueSession() throws {
        var model = AppModel()
        let clock = MutableClock(Date(timeIntervalSince1970: 1_700_000_000))
        var ids: [UUID] = []
        for index in 0..<12 {
            clock.advance(by: 60)
            let stored = try model.startNewSession(players: ["A", "B", "C", "\(index)"], chaoTable: .hongKongDefault, clock: clock)
            ids.append(stored.id)
            if index < 11 { try model.finishCurrentSession(clock: clock) }
        }
        XCTAssertEqual(model.latestUnfinished?.id, ids[11])
        let recent = model.homeRecentSessions
        XCTAssertEqual(recent.count, AppModel.homeRecentLimit)
        XCTAssertEqual(recent.count, 9)
        XCTAssertFalse(recent.contains { $0.id == ids[11] })
        XCTAssertEqual(recent.first?.id, ids[10])
        XCTAssertEqual(model.allSessions.count, 12)
        XCTAssertEqual(model.allSessions.first?.id, ids[11])
        XCTAssertEqual(model.allSessions.map(\.updatedAt), model.allSessions.map(\.updatedAt).sorted(by: >))
    }
}
