import XCTest
import ScoringEngine
@testable import AppCore

final class InterfaceRegionTests: XCTestCase {

    private let names = ["阿明", "Kenny", "阿強", "阿May"]

    // MARK: - System detection

    func testTaiwanLanguageOrRegionPicksTaiwan() {
        XCTAssertEqual(InterfaceRegion.detect(preferredLanguages: ["zh-Hant-TW"], regionCode: "TW"), .taiwan)
        XCTAssertEqual(InterfaceRegion.detect(preferredLanguages: ["zh-TW"], regionCode: nil), .taiwan)
        XCTAssertEqual(InterfaceRegion.detect(preferredLanguages: ["zh_Hant_TW"], regionCode: "US"), .taiwan)
        XCTAssertEqual(InterfaceRegion.detect(preferredLanguages: ["en-TW"], regionCode: "TW"), .taiwan)
        XCTAssertEqual(InterfaceRegion.detect(preferredLanguages: ["zh-Hant"], regionCode: "tw"), .taiwan)
    }

    func testHongKongAndEverythingElsePicksHongKong() {
        XCTAssertEqual(InterfaceRegion.detect(preferredLanguages: ["zh-Hant-HK"], regionCode: "HK"), .hongKong)
        XCTAssertEqual(InterfaceRegion.detect(preferredLanguages: ["en-HK"], regionCode: "HK"), .hongKong)
        XCTAssertEqual(InterfaceRegion.detect(preferredLanguages: ["en-GB"], regionCode: "GB"), .hongKong)
        XCTAssertEqual(InterfaceRegion.detect(preferredLanguages: [], regionCode: nil), .hongKong)
        XCTAssertEqual(InterfaceRegion.detect(preferredLanguages: ["zh-Hans-CN"], regionCode: "CN"), .hongKong)
        XCTAssertEqual(InterfaceRegion.detect(preferredLanguages: ["vi-VN", "zh-Hant-TW"], regionCode: "VN"), .hongKong)
    }

    func testExplicitHongKongLanguageWinsOverTaiwanRegion() {
        XCTAssertEqual(InterfaceRegion.detect(preferredLanguages: ["zh-Hant-HK"], regionCode: "TW"), .hongKong)
        XCTAssertEqual(InterfaceRegion.detect(preferredLanguages: ["zh-Hant-MO"], regionCode: "TW"), .hongKong)
    }

    func testPreferenceResolution() {
        XCTAssertEqual(InterfaceRegionPreference.system.resolved(systemRegion: .taiwan), .taiwan)
        XCTAssertEqual(InterfaceRegionPreference.system.resolved(systemRegion: .hongKong), .hongKong)
        XCTAssertEqual(InterfaceRegionPreference.hongKong.resolved(systemRegion: .taiwan), .hongKong)
        XCTAssertEqual(InterfaceRegionPreference.taiwan.resolved(systemRegion: .hongKong), .taiwan)
        XCTAssertEqual(InterfaceRegionPreference.system.title(in: .hongKong), "跟系統")
        XCTAssertEqual(InterfaceRegionPreference.system.title(in: .taiwan), "跟隨系統")
        XCTAssertEqual(InterfaceRegion.taiwan.localizationIdentifier, "zh-Hant-TW")
        XCTAssertEqual(InterfaceRegion.hongKong.localizationIdentifier, "zh-Hant-HK")
    }

    // MARK: - Presets

    func testTaiwanPresetTableAndCopy() {
        XCTAssertEqual(RulePreset.taiwanCommon.rule, .taiwanCommon)
        XCTAssertEqual(RulePreset.taiwanCommon.displayName(in: .taiwan), "台灣常見")
        XCTAssertEqual(RulePreset.taiwanCommon.summary(in: .taiwan), "1-9張 ×1 · 10-12張 ×2 · 13張 ×3")
        XCTAssertEqual(RulePreset.noMultiplier.displayName(in: .taiwan), "不加倍")
        XCTAssertEqual(RulePreset.hongKongDefault.displayName(in: .taiwan), "香港算法")
        XCTAssertEqual(RulePreset.hongKongDefault.displayName(in: .hongKong), "香港炒")
    }

    func testRegionPresetListsAndDefaults() {
        XCTAssertEqual(InterfaceRegion.hongKong.defaultRulePreset, .hongKongDefault)
        XCTAssertEqual(InterfaceRegion.taiwan.defaultRulePreset, .taiwanCommon)
        XCTAssertEqual(InterfaceRegion.hongKong.rulePresets, [.hongKongDefault, .noMultiplier, .classic])
        XCTAssertEqual(InterfaceRegion.taiwan.rulePresets, [.taiwanCommon, .hongKongDefault, .noMultiplier])
        XCTAssertEqual(RulePreset.classic.equivalent(in: .taiwan), .taiwanCommon)
        XCTAssertEqual(RulePreset.taiwanCommon.equivalent(in: .hongKong), .classic)
        XCTAssertEqual(RulePreset.noMultiplier.equivalent(in: .taiwan), .noMultiplier)
    }

    func testMatchingRuleUsesRegionLabel() throws {
        XCTAssertEqual(RulePreset(matching: .taiwanCommon, in: .taiwan), .taiwanCommon)
        XCTAssertEqual(RulePreset(matching: .taiwanCommon, in: .hongKong), .classic)
        XCTAssertEqual(RulePreset(matching: .classic, in: .taiwan), .taiwanCommon)
        XCTAssertEqual(RulePreset(matching: .hongKongDefault, in: .taiwan), .hongKongDefault)
        let custom = try ScoringRule(tiers: [
            MultiplierTier(minCards: 1, maxCards: 4, multiplier: 1),
            MultiplierTier(minCards: 5, maxCards: 13, multiplier: 5)
        ])
        XCTAssertEqual(RulePreset(matching: custom, in: .taiwan), .taiwanCommon)
        XCTAssertEqual(RulePreset(matching: custom, in: .hongKong), .hongKongDefault)
    }

    func testCustomRuleStillScoresInASession() throws {
        let custom = try ScoringRule(tiers: [
            MultiplierTier(minCards: 1, maxCards: 9, multiplier: 1),
            MultiplierTier(minCards: 10, maxCards: 13, multiplier: 2)
        ])
        var session = try Session(players: names, rule: custom)
        try session.addRound(cardsLeft: [0, 9, 10, 13])
        XCTAssertEqual(session.totals, [55, -9, -20, -26])
    }

    // MARK: - New session defaults

    func testFreshInstallUsesRegionDefaultPreset() {
        let model = AppModel()
        XCTAssertEqual(model.newSessionDraft(region: .taiwan).preset, .taiwanCommon)
        XCTAssertEqual(model.newSessionDraft(region: .hongKong).preset, .hongKongDefault)
    }

    func testTaiwanSessionUsesTaiwanTable() throws {
        var model = AppModel()
        let draft = model.newSessionDraft(region: .taiwan)
        let stored = try model.startNewSession(players: names, preset: draft.preset)
        XCTAssertEqual(stored.session.rule, .taiwanCommon)
        let round = try model.addRound(cardsLeft: [10, 0, 13, 3])
        XCTAssertEqual(round.points, [-20, 62, -39, -3])
    }

    func testRememberedPresetSurvivesAndMapsAcrossRegions() throws {
        var model = AppModel()
        _ = try model.startNewSession(players: names, preset: .noMultiplier)
        XCTAssertEqual(model.newSessionDraft(region: .taiwan).preset, .noMultiplier)
        _ = try model.startNewSession(players: names, preset: .classic)
        XCTAssertEqual(model.newSessionDraft(region: .taiwan).preset, .taiwanCommon)
        XCTAssertEqual(model.newSessionDraft(region: .hongKong).preset, .classic)
    }

    func testSwitchingRegionSwapsDefaultPreset() throws {
        var model = AppModel()
        _ = try model.startNewSession(players: names, preset: .hongKongDefault)
        model.setInterfaceRegionPreference(.taiwan, systemRegion: .hongKong)
        XCTAssertEqual(model.data.regionPreference, .taiwan)
        XCTAssertEqual(model.data.lastSettings.rulePreset, .taiwanCommon)
        XCTAssertEqual(model.newSessionDraft(region: .taiwan).preset, .taiwanCommon)

        model.setInterfaceRegionPreference(.system, systemRegion: .hongKong)
        XCTAssertEqual(model.data.lastSettings.rulePreset, .hongKongDefault)

        // A non-default choice is kept when switching.
        model.data.lastSettings.rulePreset = .noMultiplier
        model.setInterfaceRegionPreference(.taiwan, systemRegion: .hongKong)
        XCTAssertEqual(model.data.lastSettings.rulePreset, .noMultiplier)
    }

    func testSwitchingToSameEffectiveRegionChangesNothing() throws {
        var model = AppModel()
        _ = try model.startNewSession(players: names, preset: .hongKongDefault)
        model.setInterfaceRegionPreference(.hongKong, systemRegion: .hongKong)
        XCTAssertEqual(model.data.lastSettings.rulePreset, .hongKongDefault)
    }

    // MARK: - Wording

    func testTaiwanWordingHasNoCantoneseParticles() throws {
        let tw = ScoreFormatting(region: .taiwan)
        let round = try ScoringEngine.score(cardsLeft: [5, 0, 9, 11], rule: .taiwanCommon)
        let displays = RoundPresentation.displays(from: round)
        let receipts = RoundPresentation.winnerReceipts(from: round)
        XCTAssertEqual(tw.roundDetail(score: displays[1], winnerReceivedFrom: receipts), "出完牌，收 5 + 9 + 22")
        XCTAssertEqual(tw.afterRoundTitle(0), "尚未開局")
        XCTAssertEqual(tw.homeProgress(0), "尚未開局")
        XCTAssertEqual(tw.homeProgress(5), "已進行 5 局")
        XCTAssertEqual(tw.appTitle, "大老二記分")

        var state = RoundEntryState(rule: .taiwanCommon)
        XCTAssertEqual(state.hintText(in: .taiwan), "點「贏」選出誰先出完牌")
        XCTAssertEqual(state.padPrompt(playerNames: names, region: .taiwan), "先選贏家")
        state = RoundEntryState(rule: .taiwanCommon)

        let cantonese = ["㩒", "揀", "嘅", "咗", "唔", "係", "喇", "緊", "幾多", "呢", "嚟", "冇"]
        let texts = [
            tw.afterRoundTitle(0), tw.appTitle,
            tw.roundDetail(score: displays[1], winnerReceivedFrom: receipts),
            state.hintText(in: .taiwan), state.padPrompt(playerNames: names, region: .taiwan),
            RulePreset.noMultiplier.summary(in: .taiwan),
            RulePreset.noMultiplier.displayName(in: .taiwan),
            InterfaceRegionPreference.system.title(in: .taiwan)
        ]
        for text in texts {
            for particle in cantonese {
                XCTAssertFalse(text.contains(particle), "\(text) contains \(particle)")
            }
        }
    }

    func testTaiwanShareSummary() throws {
        var session = try Session(players: names, rule: .taiwanCommon)
        try session.addRound(cardsLeft: [5, 0, 9, 11])
        let stored = StoredSession(
            session: session,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            endedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let summary = ShareSummary(stored: stored, format: ScoreFormatting(region: .taiwan))
        XCTAssertEqual(summary.title, "大老二記分")
        XCTAssertEqual(summary.ruleLine, "台灣常見（1-9張 ×1 · 10-12張 ×2 · 13張 ×3）")
        XCTAssertFalse(summary.text.contains("$"))
    }

    // MARK: - Persistence

    func testOldDataWithoutRegionOrMoneyFieldsStillDecodes() throws {
        var data = AppData()
        data.lastSettings = LastSettings(playerNames: names, rulePreset: .classic)
        var object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(data)) as! [String: Any]
        XCTAssertNil(object["interfaceRegionPreference"])
        var last = object["lastSettings"] as! [String: Any]
        last["pointValue"] = 2  // written by builds that still had 每分幾錢
        object["lastSettings"] = last
        let decoded = try JSONDecoder().decode(AppData.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertEqual(decoded.regionPreference, .system)
        XCTAssertEqual(decoded.lastSettings.rulePreset, .classic)
    }

    func testRegionPreferenceRoundTrips() throws {
        var data = AppData()
        data.interfaceRegionPreference = .taiwan
        let decoded = try JSONDecoder().decode(AppData.self, from: JSONEncoder().encode(data))
        XCTAssertEqual(decoded.regionPreference, .taiwan)
    }
}
