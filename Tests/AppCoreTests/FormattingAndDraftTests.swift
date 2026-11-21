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
        XCTAssertEqual(format.roundDetail(score: displays[1]), "出晒")
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
        XCTAssertEqual(format.roundDetail(score: d[0]), "出晒")
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
        XCTAssertEqual(theme.keyColor(forMultiplier: 1), theme.keyBackground)
        XCTAssertEqual(theme.keyColor(forMultiplier: 2).hexString, "#F5C542")
        XCTAssertEqual(theme.keyColor(forMultiplier: 3).hexString, "#E38B2C")
        XCTAssertEqual(theme.keyColor(forMultiplier: 4).hexString, "#C8372D")
        XCTAssertEqual(theme.keyTextColor(forMultiplier: 4).hexString, "#FFFFFF")
    }

    func testDualSkinTokensMatchHandoff() {
        // Two fixed looks (Kenny, 2026-11-20): 經典 always dark, Ledger always light.
        let classic = Theme.make(skin: .classic)
        XCTAssertTrue(classic.isDark)
        XCTAssertEqual(classic.background.hexString, "#1E2128")
        XCTAssertEqual(classic.card.hexString, "#2A2E37")
        XCTAssertEqual(classic.primary.hexString, "#F5C542")
        XCTAssertEqual(classic.primaryText.hexString, "#1E2128")
        XCTAssertEqual(classic.keyColor(forMultiplier: 2).hexString, "#F5C542")
        XCTAssertEqual(classic.keyColor(forMultiplier: 3).hexString, "#E38B2C")
        XCTAssertEqual(classic.keyColor(forMultiplier: 4).hexString, "#C8372D")
        XCTAssertEqual(classic.cardCornerRadius, 16)
        XCTAssertEqual(classic.buttonCornerRadius, 18)
        XCTAssertEqual(classic.keyCornerRadius, 12)
        XCTAssertEqual(classic.cardBorderWidth, 0)
        XCTAssertFalse(classic.monoNumbers)
        XCTAssertFalse(classic.suitOutline)
        XCTAssertEqual(classic.suitBlack.hexString, "#3A3F4B")

        let ledger = Theme.make(skin: .ledger)
        XCTAssertFalse(ledger.isDark)
        XCTAssertEqual(ledger.background.hexString, "#FFFFFF")
        XCTAssertEqual(ledger.primary.hexString, "#2F5BFF")
        XCTAssertEqual(ledger.primaryText.hexString, "#FFFFFF")
        XCTAssertEqual(ledger.keyColor(forMultiplier: 2).hexString, "#2F5BFF")
        XCTAssertEqual(ledger.keyColor(forMultiplier: 4).hexString, "#C9363B")
        XCTAssertEqual(ledger.cardCornerRadius, 10)
        XCTAssertEqual(ledger.keyCornerRadius, 8)
        XCTAssertEqual(ledger.cardBorderWidth, 1)
        XCTAssertTrue(ledger.monoNumbers)
        XCTAssertTrue(ledger.squareMarker)
        XCTAssertTrue(ledger.suitOutline)
        XCTAssertEqual(ledger.suitRed.hexString, "#AFC0F7")

        XCTAssertEqual(SkinID.ledger.alternateIconName, "AppIcon-Ledger")
        XCTAssertNil(SkinID.classic.alternateIconName)
        XCTAssertEqual(SkinID.ledger.displayName, "Ledger")
    }

    func testLedgerHiSoftMatchesTokens() {
        let ledger = Theme.make(skin: .ledger)
        let classic = Theme.make(skin: .classic)
        XCTAssertEqual(ledger.hiSoft, AppCore.RGBColor(hex: 0xE6ECFF))
        XCTAssertEqual(classic.hiSoft, AppCore.RGBColor(hex: 0x4A3F1E))
        XCTAssertEqual(ledger.hi.hexString, "#2F5BFF")
        XCTAssertEqual(ledger.chipHiInk.hexString, "#2A52E8")
        XCTAssertEqual(classic.chipHiInk, classic.hi)
    }

    /// WCAG AA (4.5:1) for text on every button / key fill in both looks.
    func testButtonTextContrastMeetsWCAGAA() {
        func luminance(_ c: AppCore.RGBColor) -> Double {
            func lin(_ v: Double) -> Double { v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
            return 0.2126 * lin(c.red) + 0.7152 * lin(c.green) + 0.0722 * lin(c.blue)
        }
        func ratio(_ a: AppCore.RGBColor, _ b: AppCore.RGBColor) -> Double {
            let la = luminance(a), lb = luminance(b)
            return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
        }
        for skin in SkinID.allCases {
            let t = Theme.make(skin: skin)
            let pairs: [(String, AppCore.RGBColor, AppCore.RGBColor)] = [
                ("primary", t.primaryText, t.primary),
                ("disabled", t.secondaryText, t.surface2),
                ("secondary", t.text, t.surface2),
                ("key ×1", t.keyTextColor(forMultiplier: 1), t.keyColor(forMultiplier: 1)),
                ("key ×2", t.keyTextColor(forMultiplier: 2), t.keyColor(forMultiplier: 2)),
                ("key ×3", t.keyTextColor(forMultiplier: 3), t.keyColor(forMultiplier: 3)),
                ("key ×4", t.keyTextColor(forMultiplier: 4), t.keyColor(forMultiplier: 4)),
                ("badge ×2", AppCore.RGBColor(hex: 0xFFFFFF), t.badgeColor(forMultiplier: 2)),
                ("badge ×3", AppCore.RGBColor(hex: 0xFFFFFF), t.badgeColor(forMultiplier: 3)),
                ("badge ×4", AppCore.RGBColor(hex: 0xFFFFFF), t.badgeColor(forMultiplier: 4)),
                ("destructive fill", AppCore.RGBColor(hex: 0xFFFFFF), t.destructiveFill),
                ("destructive text", t.negative, t.card),
                ("link", t.accentLink, t.background),
                ("×2 chip", t.chipHiInk, t.hiSoft),
                // 15pt bold 贏家 badges still use brand `hi` on hiSoft.
                ("winner hi", t.hi, t.hiSoft),
            ]
            for (name, fg, bg) in pairs {
                // Ledger brand hi on hiSoft is ~4.38:1, under 4.5 for 13pt text
                // but OK for large-text 贏家 badges (3:1). Chip labels use
                // chipHiInk (#2A52E8, 5.13:1) and must meet 4.5 in both skins.
                let minimum = (skin == .ledger && name == "winner hi") ? 3.0 : 4.5
                XCTAssertGreaterThanOrEqual(ratio(fg, bg), minimum, "\(skin) \(name)")
            }
        }
    }

    @MainActor
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
