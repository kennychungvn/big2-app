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

    // MARK: - 炒法 defaults

    func testRegionDefaultChaoTables() {
        XCTAssertEqual(InterfaceRegion.hongKong.defaultChaoTable.multipliers, [2, 2, 3, 3, 3, 4])
        XCTAssertEqual(InterfaceRegion.taiwan.defaultChaoTable.multipliers, [1, 1, 2, 2, 2, 3])
        XCTAssertEqual(InterfaceRegion.hongKong.defaultChaoTable.rule, .hongKongDefault)
        XCTAssertEqual(InterfaceRegion.taiwan.defaultChaoTable.rule, .taiwanCommon)
    }

    func testCustomRuleStillScoresInASession() throws {
        let custom = try ScoringRule(tiers: [
            MultiplierTier(minCards: 1, maxCards: 9, multiplier: 1),
            MultiplierTier(minCards: 10, maxCards: 13, multiplier: 2)
        ])
        var session = try Session(players: names, rule: custom)
        try session.addRound(cardsLeft: [0, 9, 10, 13])
        XCTAssertEqual(session.totals, [55, 19, -25, -49])  // pairwise: P = 55, 55 − 4p
    }

    // MARK: - New session defaults

    func testFreshInstallUsesRegionDefaultTable() {
        let model = AppModel()
        let tw = model.newSessionDraft(region: .taiwan)
        XCTAssertEqual(tw.chaoTable, .taiwanDefault)
        XCTAssertFalse(tw.usesRememberedChao)
        let hk = model.newSessionDraft(region: .hongKong)
        XCTAssertEqual(hk.chaoTable, .hongKongDefault)
        XCTAssertFalse(hk.usesRememberedChao)
    }

    func testTaiwanSessionUsesTaiwanTable() throws {
        var model = AppModel()
        let draft = model.newSessionDraft(region: .taiwan)
        let stored = try model.startNewSession(
            players: names,
            chaoTable: draft.chaoTable,
            scoringMode: InterfaceRegion.taiwan.defaultScoringMode
        )
        XCTAssertEqual(stored.session.rule, .taiwanCommon)
        XCTAssertEqual(stored.session.scoringMode, .winnerTakesAll)
        let round = try model.addRound(cardsLeft: [10, 0, 13, 3])
        XCTAssertEqual(round.points, [-20, 62, -39, -3])
    }

    func testRememberedTableIsPrefilledInEitherRegion() throws {
        var model = AppModel()
        let custom = ChaoTable(multipliers: [1, 2, 2, 3, 4, 4])
        _ = try model.startNewSession(players: names, chaoTable: custom)
        XCTAssertEqual(model.data.lastSettings.chaoTable, custom)
        for region in InterfaceRegion.allCases {
            let draft = model.newSessionDraft(region: region)
            XCTAssertEqual(draft.chaoTable, custom)
            XCTAssertTrue(draft.usesRememberedChao)
        }
    }

    func testSwitchingRegionSwapsOnlyAnUntouchedDefault() throws {
        var model = AppModel()
        _ = try model.startNewSession(players: names, chaoTable: .hongKongDefault)
        model.setInterfaceRegionPreference(.taiwan, systemRegion: .hongKong)
        XCTAssertEqual(model.data.regionPreference, .taiwan)
        XCTAssertEqual(model.data.lastSettings.chaoTable, .taiwanDefault)
        XCTAssertEqual(model.newSessionDraft(region: .taiwan).chaoTable, .taiwanDefault)

        model.setInterfaceRegionPreference(.system, systemRegion: .hongKong)
        XCTAssertEqual(model.data.lastSettings.chaoTable, .hongKongDefault)

        // Anything the players picked themselves is kept.
        let custom = ChaoTable(multipliers: [2, 2, 2, 3, 3, 4])
        model.data.lastSettings.chaoTable = custom
        model.setInterfaceRegionPreference(.taiwan, systemRegion: .hongKong)
        XCTAssertEqual(model.data.lastSettings.chaoTable, custom)
        model.data.lastSettings.chaoTable = .noMultiplier
        model.setInterfaceRegionPreference(.hongKong, systemRegion: .hongKong)
        XCTAssertEqual(model.data.lastSettings.chaoTable, .noMultiplier)
    }

    func testSwitchingRegionWithNothingRememberedKeepsNil() {
        var model = AppModel()
        model.setInterfaceRegionPreference(.taiwan, systemRegion: .hongKong)
        XCTAssertNil(model.data.lastSettings.chaoTable)
        XCTAssertEqual(model.newSessionDraft(region: .taiwan).chaoTable, .taiwanDefault)
    }

    func testSwitchingToSameEffectiveRegionChangesNothing() throws {
        var model = AppModel()
        _ = try model.startNewSession(players: names, chaoTable: .hongKongDefault)
        model.setInterfaceRegionPreference(.hongKong, systemRegion: .hongKong)
        XCTAssertEqual(model.data.lastSettings.chaoTable, .hongKongDefault)
    }

    // MARK: - Wording

    func testTaiwanWordingHasNoCantoneseParticles() throws {
        let tw = ScoreFormatting(region: .taiwan)
        let round = try ScoringEngine.score(cardsLeft: [5, 0, 9, 11], rule: .taiwanCommon)
        let displays = RoundPresentation.displays(from: round)
        XCTAssertEqual(tw.roundDetail(score: displays[1]), "出完")

        XCTAssertEqual(tw.homeProgress(0), "尚未開局")
        XCTAssertEqual(tw.homeProgress(5), "已進行 5 局")
        XCTAssertEqual(tw.appTitle, "大老二記分")

        var state = RoundEntryState(rule: .taiwanCommon)
        XCTAssertEqual(state.hintText(in: .taiwan), "依序輸入剩幾張，先出完的點「贏」")
        XCTAssertEqual(state.padPrompt(playerNames: names, region: .taiwan), "阿明 剩幾張？")
        state.enterCards(5)
        XCTAssertEqual(state.hintText(in: .taiwan), "輸入後會自動跳到下一位，點任一列可修改")

        let cantonese = ["㩒", "揀", "嘅", "咗", "唔", "係", "喇", "緊", "幾多", "呢", "嚟", "冇"]
        let texts = [
            tw.homeProgress(0), tw.homeProgress(3), tw.appTitle,
            tw.roundDetail(score: displays[1]), tw.roundDetail(score: displays[3]),
            state.hintText(in: .taiwan), state.padPrompt(playerNames: names, region: .taiwan),
            tw.ruleSummary(ScoringRule.noMultiplier),
            tw.ruleSummary(ScoringRule.taiwanCommon),
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
        XCTAssertEqual(summary.ruleLine, "10-12張×2 · 13張×3")
        XCTAssertTrue(summary.text.contains("10-12張×2 · 13張×3"))
        XCTAssertFalse(summary.text.contains("$"))
    }

    // MARK: - Persistence

    func testOldDataWithoutRegionOrMoneyFieldsStillDecodes() throws {
        var data = AppData()
        data.lastSettings = LastSettings(playerNames: names)
        var object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(data)) as! [String: Any]
        XCTAssertNil(object["interfaceRegionPreference"])
        var last = object["lastSettings"] as! [String: Any]
        last["pointValue"] = 2  // written by builds that still had 每分幾錢
        last["rulePreset"] = "classic"  // written by builds with fixed presets
        object["lastSettings"] = last
        let decoded = try JSONDecoder().decode(AppData.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertEqual(decoded.regionPreference, .system)
        XCTAssertEqual(decoded.lastSettings.playerNames, names)
        XCTAssertEqual(decoded.lastSettings.chaoTable, .taiwanDefault)
    }

    func testEveryLegacyPresetMigrates() throws {
        let expected: [String: ChaoTable] = [
            "hongKongDefault": .hongKongDefault,
            "noMultiplier": .noMultiplier,
            "classic": .taiwanDefault,
            "taiwanCommon": .taiwanDefault
        ]
        for (raw, table) in expected {
            let json = #"{"playerNames":["A","B","C","D"],"rulePreset":"\#(raw)"}"#
            let decoded = try JSONDecoder().decode(LastSettings.self, from: Data(json.utf8))
            XCTAssertEqual(decoded.chaoTable, table, raw)
        }
        let unknown = #"{"playerNames":["A"],"rulePreset":"somethingNew"}"#
        let decoded = try JSONDecoder().decode(LastSettings.self, from: Data(unknown.utf8))
        XCTAssertNil(decoded.chaoTable)
        XCTAssertEqual(decoded.playerNames, ["A", "", "", ""])
    }

    func testMigratedPresetWithoutSessionsStillShowsFirstTimeDefault() throws {
        // Old builds always wrote a preset, even before the first session.
        let json = #"{"schemaVersion":1,"sessions":[],"lastSettings":{"playerNames":["","","",""],"rulePreset":"hongKongDefault"},"knownPlayerNames":[],"adsRemoved":false,"chaoAnimationEnabled":true,"hapticsEnabled":true}"#
        let data = try JSONDecoder().decode(AppData.self, from: Data(json.utf8))
        let draft = AppModel(data: data).newSessionDraft(region: .taiwan)
        XCTAssertEqual(draft.chaoTable, .taiwanDefault)
        XCTAssertFalse(draft.usesRememberedChao)
    }

    func testOldSavedSessionWithClassicRuleLoadsAndSummarises() throws {
        var session = try Session(players: names, rule: .classic)
        try session.addRound(cardsLeft: [5, 0, 9, 11])
        let stored = StoredSession(session: session, createdAt: Date(timeIntervalSince1970: 1_700_000_000))
        var data = AppData(sessions: [stored])
        data.lastSettings = LastSettings(playerNames: names)
        var object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(data)) as! [String: Any]
        var last = object["lastSettings"] as! [String: Any]
        last["rulePreset"] = "classic"
        object["lastSettings"] = last
        let decoded = try JSONDecoder().decode(AppData.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertEqual(decoded.sessions.first?.session.rule, .classic)
        XCTAssertEqual(decoded.sessions.first?.session.totals, session.totals)
        XCTAssertEqual(ScoreFormatting().ruleSummary(decoded.sessions[0].session.rule), "10-12張×2 · 13張×3")
        let draft = AppModel(data: decoded).newSessionDraft(region: .hongKong)
        XCTAssertEqual(draft.chaoTable, .taiwanDefault)
        XCTAssertTrue(draft.usesRememberedChao)
    }

    func testNewSettingsRoundTripWithoutLegacyKey() throws {
        let settings = LastSettings(playerNames: names, chaoTable: ChaoTable(multipliers: [4, 1, 3, 1, 2, 1]))
        let encoded = try JSONEncoder().encode(settings)
        let object = try JSONSerialization.jsonObject(with: encoded) as! [String: Any]
        XCTAssertNil(object["rulePreset"])
        XCTAssertEqual(try JSONDecoder().decode(LastSettings.self, from: encoded), settings)
    }

    func testRegionPreferenceRoundTrips() throws {
        var data = AppData()
        data.interfaceRegionPreference = .taiwan
        let decoded = try JSONDecoder().decode(AppData.self, from: JSONEncoder().encode(data))
        XCTAssertEqual(decoded.regionPreference, .taiwan)
    }
}

final class TaiwanFeatureFlagTests: XCTestCase {
    func testTaiwanIsOffByDefault() {
        XCTAssertFalse(FeatureFlags.taiwanEnabledByDefault, "Taiwan is on hold until its scoring is decided")
    }

    func testFlagOffAlwaysResolvesHongKong() {
        var data = AppData()
        XCTAssertEqual(data.interfaceRegion(systemRegion: .taiwan, taiwanEnabled: false), .hongKong)
        data.interfaceRegionPreference = .taiwan
        XCTAssertEqual(data.interfaceRegion(systemRegion: .taiwan, taiwanEnabled: false), .hongKong)
        XCTAssertEqual(data.interfaceRegion(systemRegion: .taiwan, taiwanEnabled: true), .taiwan)
        data.interfaceRegionPreference = .system
        XCTAssertEqual(data.interfaceRegion(systemRegion: .taiwan, taiwanEnabled: true), .taiwan)
        XCTAssertEqual(data.interfaceRegion(systemRegion: .hongKong, taiwanEnabled: true), .hongKong)
    }
}
