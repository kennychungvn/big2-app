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
        XCTAssertEqual(format.homeProgress(0), "未開始")
        XCTAssertEqual(format.homeProgress(5), "打咗 5 局")
        XCTAssertEqual(format.resultTitle(6), "第 6 局結果")
        // 1_700_000_000 is 2023-11-14 22:13:20 UTC = 2023-11-15 06:13 HKT
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        XCTAssertEqual(format.shortDate(date), "2023/11/15")
        XCTAssertEqual(format.sessionListSubtitle(date: date, rounds: 24), "2023/11/15 · 24 局")
        XCTAssertEqual(ScoreFormatting(region: .taiwan).sessionListSubtitle(date: date, rounds: 18), "2023/11/15 · 18 局")
    }

    func testRoundDetailShowsCardsAndNetPointsSeparately() throws {
        let round = try ScoringEngine.score(cardsLeft: [5, 0, 9, 11], rule: .hongKongDefault, mode: .pairwise)
        let displays = RoundPresentation.displays(from: round)
        // penalties 5 / 0 / 18 / 33, P = 56 → 56 − 4p
        XCTAssertEqual(displays.map(\.points), [36, 56, -16, -76])
        XCTAssertEqual(format.roundDetail(score: displays[1]), "出清牌")
        XCTAssertFalse(format.roundDetail(score: displays[1]).contains("收"))
        XCTAssertEqual(format.roundDetail(score: displays[0]), "5 張 ×1")
        XCTAssertEqual(format.roundDetail(score: displays[2]), "9 張 ×2")
        XCTAssertEqual(format.roundDetail(score: displays[3]), "11 張 ×3")
        XCTAssertFalse(format.roundDetail(score: displays[3]).contains("🔥"))
    }

    /// No 炒到盡 / 最高倍 wording anywhere: every 炒倍 is just `N 張 ×M`.
    func testRoundDetailHasNoMaxWording() throws {
        let round = try ScoringEngine.score(cardsLeft: [0, 11, 13, 3], rule: .hongKongDefault, mode: .pairwise)
        let d = RoundPresentation.displays(from: round)
        XCTAssertEqual(format.roundDetail(score: d[2]), "13 張 ×4")
        XCTAssertEqual(ScoreFormatting(region: .taiwan).roundDetail(score: d[2]), "13 張 ×4")
        XCTAssertEqual(format.roundDetail(score: d[1]), "11 張 ×3")
        XCTAssertEqual(format.roundDetail(score: d[0]), "出清牌")
    }

    func testResultTotalsHeader() {
        XCTAssertEqual(format.resultTotalsHeader(6), "累計 · 打咗 6 局")
        XCTAssertEqual(ScoreFormatting(region: .taiwan).resultTotalsHeader(6), "累計 · 已進行 6 局")
    }

    func testLegacyPresetsMapToChaoTables() {
        XCTAssertEqual(RulePreset.hongKongDefault.chaoTable, .hongKongDefault)
        XCTAssertEqual(RulePreset.noMultiplier.chaoTable, .noMultiplier)
        XCTAssertEqual(RulePreset.classic.chaoTable, .taiwanDefault)
        XCTAssertEqual(RulePreset.taiwanCommon.chaoTable, .taiwanDefault)
    }

    func testNewSessionDraftChipFillAndValidation() {
        var draft = NewSessionDraft(from: LastSettings(playerNames: ["阿明", "Kenny", "", ""], chaoTable: .hongKongDefault))
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
        XCTAssertTrue(summary.text.contains("鋤大D計分"))
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
        XCTAssertEqual(theme.keyColor(forMultiplier: 1), theme.keyBackground)
        XCTAssertEqual(theme.keyColor(forMultiplier: 2).hexString, "#F5C542")
        XCTAssertEqual(theme.keyColor(forMultiplier: 3).hexString, "#E38B2C")
        XCTAssertEqual(theme.keyColor(forMultiplier: 4).hexString, "#C8372D")
        XCTAssertEqual(theme.keyTextColor(forMultiplier: 2), theme.primaryText)
        XCTAssertEqual(theme.keyTextColor(forMultiplier: 4), theme.text)
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
