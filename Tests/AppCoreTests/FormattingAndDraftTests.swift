import XCTest
import ScoringEngine
@testable import AppCore

final class FormattingAndDraftTests: XCTestCase {

    let format = ScoreFormatting()

    func testPointsUseTypographicMinus() {
        XCTAssertEqual(format.points(56), "+56")
        XCTAssertEqual(format.points(-5), "−5")
        XCTAssertEqual(format.points(0), "0")
    }

    func testRoundAndDateTitles() {
        XCTAssertEqual(format.roundTitle(6), "第 6 局")
        XCTAssertEqual(format.afterRoundTitle(6), "第 6 局後")
        XCTAssertEqual(format.afterRoundTitle(0), "未開局")
        XCTAssertEqual(format.resultTitle(6), "第 6 局結果")
        // 1_700_000_000 is 2023-11-14 22:13:20 UTC = 2023-11-15 06:13 HKT
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        XCTAssertEqual(format.shortDate(date), "11月15日")
        XCTAssertEqual(format.sessionListSubtitle(date: date, rounds: 24), "11月15日 · 24 局")
    }

    func testRoundDetailAndWinnerReceipts() throws {
        let round = try ScoringEngine.score(cardsLeft: [5, 0, 9, 11], rule: .hongKongDefault)
        let displays = RoundPresentation.displays(from: round)
        let receipts = RoundPresentation.winnerReceipts(from: round)
        XCTAssertEqual(receipts, [5, 18, 33])
        XCTAssertEqual(format.roundDetail(score: displays[1], winnerReceivedFrom: receipts), "出清牌，收 5 + 18 + 33")
        XCTAssertEqual(format.roundDetail(score: displays[0]), "5 張 ×1")
        XCTAssertEqual(format.roundDetail(score: displays[2]), "9 張 ×2")
        XCTAssertEqual(format.roundDetail(score: displays[3]), "11 張 ×3 🔥")
    }

    func testRulePresetCopy() {
        XCTAssertEqual(RulePreset.hongKongDefault.displayName, "香港炒")
        XCTAssertEqual(RulePreset.noMultiplier.displayName, "唔炒")
        XCTAssertEqual(RulePreset.classic.displayName, "經典")
        XCTAssertEqual(RulePreset(matching: .classic), .classic)
        XCTAssertEqual(RulePreset.hongKongDefault.rule, .hongKongDefault)
    }

    func testNewSessionDraftChipFillAndValidation() {
        var draft = NewSessionDraft(from: LastSettings(playerNames: ["阿明", "Kenny", "", ""], rulePreset: .hongKongDefault))
        XCTAssertFalse(draft.canStart)
        XCTAssertTrue(draft.applyChip("阿強"))
        XCTAssertTrue(draft.applyChip("阿May"))
        XCTAssertFalse(draft.applyChip("細佬"))
        XCTAssertEqual(draft.names, ["阿明", "Kenny", "阿強", "阿May"])
        XCTAssertTrue(draft.canStart)
    }

    func testShareSummaryTextContainsStandings() throws {
        var session = try Session(players: ["阿明", "Kenny", "阿強", "阿May"])
        try session.addRound(cardsLeft: [5, 0, 9, 11])
        let stored = StoredSession(
            session: session,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            endedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let summary = ShareSummary(stored: stored)
        XCTAssertTrue(summary.text.contains("鋤大Dee 計分"))
        XCTAssertTrue(summary.text.contains("Kenny"))
        XCTAssertTrue(summary.text.contains("+56"))
        XCTAssertTrue(summary.text.contains("👑"))
        XCTAssertTrue(summary.rows.first?.isLeader == true)
        XCTAssertEqual(summary.rows.first?.name, "Kenny")
        XCTAssertFalse(summary.text.contains("$"), "share text must be points only")
        XCTAssertFalse(summary.text.contains("每分"))
    }

    func testNeighbourhoodThemeTokensMatchWireframe() {
        let theme = Theme.neighbourhood
        XCTAssertEqual(theme.background.hexString, "#1E2128")
        XCTAssertEqual(theme.card.hexString, "#2A2E37")
        XCTAssertEqual(theme.primary.hexString, "#F5C542")
        XCTAssertEqual(theme.playerColors.map(\.hexString), ["#4A8CFF", "#FF5A5A", "#3CCF7A", "#FFA53C"])
        XCTAssertEqual(theme.cardCornerRadius, 16)
        XCTAssertEqual(theme.keyCornerRadius, 14)
        XCTAssertEqual(theme.chineseName, "街坊")
        XCTAssertEqual(theme.keyColor(forMultiplier: 2).hexString, "#24493A")
        XCTAssertEqual(theme.keyColor(forMultiplier: 3).hexString, "#5A3E18")
        XCTAssertEqual(theme.keyColor(forMultiplier: 4).hexString, "#6B2222")
    }

    func testStubStoreAndMockAds() async throws {
        let store = StubStoreManager()
        XCTAssertFalse(store.adsRemoved)
        let purchased = try await store.purchaseRemoveAds()
        XCTAssertTrue(purchased)
        XCTAssertTrue(store.adsRemoved)

        let ads = MockAdManager(isInterstitialReady: true)
        let shown = await ads.showInterstitialIfReady()
        XCTAssertTrue(shown)
        XCTAssertEqual(ads.showCount, 1)
        ads.adsRemoved = true
        ads.isInterstitialReady = true
        let skipped = await ads.showInterstitialIfReady()
        XCTAssertFalse(skipped)
    }
}
