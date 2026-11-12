import XCTest

/// End-to-end flow on a real simulator. Launches with `-uiTesting` so the app starts from
/// empty data, shows a closable stand-in interstitial after round 5, and uses the stub store.
/// Screenshots are attached with `.keepAlways` and exported by CI.
final class Big2UITests: XCTestCase {

    private var app: XCUIApplication!
    private var shotIndex = 0
    private var shotPrefix = ""

    override func setUp() {
        continueAfterFailure = false
    }

    // MARK: - Helpers

    private func launch(languages: String, locale: String, prefix: String, extra: [String] = []) {
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-uiTestAds", "-AppleLanguages", "(\(languages))", "-AppleLocale", locale] + extra
        app.launch()
        shotPrefix = prefix
        shotIndex = 0
    }

    private func snap(_ name: String) {
        shotIndex += 1
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = String(format: "%@-%02d-%@", shotPrefix, shotIndex, name)
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @discardableResult
    private func element(_ id: String, timeout: TimeInterval = 10, file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let element = app.descendants(matching: .any)[id].firstMatch
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "missing \(id)", file: file, line: line)
        return element
    }

    private func tap(_ id: String, file: StaticString = #filePath, line: UInt = #line) {
        let target = element(id, file: file, line: line)
        waitUntil(file: file, line: line) { target.isHittable }
        target.tap()
    }

    private func waitUntil(timeout: TimeInterval = 10, file: StaticString = #filePath, line: UInt = #line, _ condition: () -> Bool) {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        XCTFail("condition not met in \(timeout)s", file: file, line: line)
    }

    private func waitGone(_ id: String, timeout: TimeInterval = 10, file: StaticString = #filePath, line: UInt = #line) {
        let target = app.descendants(matching: .any)[id].firstMatch
        waitUntil(timeout: timeout, file: file, line: line) { !target.exists }
    }

    private func label(_ id: String) -> String {
        element(id).label
    }

    private func text(containing fragment: String) -> XCUIElement {
        app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", fragment)).firstMatch
    }

    private func assertText(_ fragment: String, file: StaticString = #filePath, line: UInt = #line) {
        let predicate = NSPredicate(format: "label CONTAINS %@", fragment)
        let match = app.descendants(matching: .any).matching(predicate).firstMatch
        XCTAssertTrue(match.waitForExistence(timeout: 10), "text not found: \(fragment)", file: file, line: line)
    }

    /// Types the four names, using the keyboard's 下一個 (return) key to move between fields.
    private func typeNames(_ names: [String]) {
        let first = element("setup.name.0")
        first.tap()
        waitUntil { (first.value(forKey: "hasKeyboardFocus") as? Bool) == true }
        for (index, name) in names.enumerated() {
            let field = element("setup.name.\(index)")
            if (field.value(forKey: "hasKeyboardFocus") as? Bool) != true {
                field.tap()
                waitUntil { (field.value(forKey: "hasKeyboardFocus") as? Bool) == true }
            }
            field.typeText(name + "\n")
        }
    }

    /// The 完場 interstitial shows only if no other ad played in the last 3 minutes.
    private func closeFinishInterstitialIfShown() {
        let close = app.descendants(matching: .any)["interstitial.close"].firstMatch
        if close.waitForExistence(timeout: 4) {
            assertNoBanner("finish-interstitial")
            snap("finish-interstitial")
            close.tap()
        }
    }

    /// Enters one round, seat by seat (0 = 贏), and waits for the result overlay.
    private func enterRound(_ cards: [Int], snapBeforeLast: String? = nil) {
        element("entry.title")
        for (seat, value) in cards.enumerated() {
            if seat == cards.count - 1, let snapBeforeLast { snap(snapBeforeLast) }
            tap(value == 0 ? "pad.win" : "pad.\(value)")
        }
        element("result.title")
    }

    /// Result sheet stays until 「下一局」 is tapped.
    private func tapNextRound() {
        tap("result.next")
        waitForScoreboard()
    }

    /// Kenny: the bottom banner is visible on every screen, sheets and covers included.
    /// A covered banner (e.g. the root one under a sheet) is not hittable, so require a hittable one.
    private func assertBanner(_ screen: String, file: StaticString = #filePath, line: UInt = #line) {
        let banners = app.descendants(matching: .any).matching(identifier: "banner")
        XCTAssertTrue(banners.firstMatch.waitForExistence(timeout: 5), "no banner on \(screen)", file: file, line: line)
        let visible = banners.allElementsBoundByIndex.contains { $0.exists && $0.isHittable }
        XCTAssertTrue(visible, "banner not visible on \(screen)", file: file, line: line)
    }

    private func assertNoBanner(_ screen: String, file: StaticString = #filePath, line: UInt = #line) {
        let banners = app.descendants(matching: .any).matching(identifier: "banner")
        let visible = banners.allElementsBoundByIndex.contains { $0.exists && $0.isHittable }
        XCTAssertFalse(visible, "banner should be hidden on \(screen)", file: file, line: line)
    }

    private func waitForScoreboard() {
        waitGone("entry.title", timeout: 12)
        element("scoreboard.addRound")
    }

    private func assertTotals(_ totals: [String], file: StaticString = #filePath, line: UInt = #line) {
        for (index, total) in totals.enumerated() {
            let card = element("scoreboard.player.\(index)", file: file, line: line)
            XCTAssertTrue(card.label.hasSuffix(" \(total)"), "player \(index): \(card.label) ≠ \(total)", file: file, line: line)
        }
    }

    // MARK: - Hong Kong full flow

    func testHongKongFullFlow() {
        launch(languages: "zh-Hant-HK", locale: "zh_HK", prefix: "HK")

        // Home (fresh)
        XCTAssertEqual(label("home.title"), "鋤大D計分")
        XCTAssertFalse(app.descendants(matching: .any)["home.allSessions"].exists)
        assertBanner("home-fresh")
        snap("home-fresh")

        // 開場設定
        tap("home.newSession")
        assertText("新開一場")
        let tile8 = element("setup.tile.8")
        XCTAssertEqual(tile8.value as? String, "×2")
        XCTAssertEqual(element("setup.tile.10").value as? String, "×3")
        XCTAssertEqual(element("setup.tile.13").value as? String, "×4")
        XCTAssertTrue(element("setup.namesHint").label.contains("要填齊 4 個玩家名"))
        XCTAssertFalse(element("setup.start").isEnabled)
        assertBanner("setup-empty")
        snap("setup-empty")
        tile8.tap()
        XCTAssertEqual(tile8.value as? String, "×3")
        tile8.tap(); tile8.tap()
        XCTAssertEqual(tile8.value as? String, "×1")
        tile8.tap()
        XCTAssertEqual(tile8.value as? String, "×2", "tile cycles back to the HK default")
        typeNames(["小肥", "文仔", "呀權", "呀南"])
        snap("setup-filled")
        tap("setup.start")

        // Scoreboard, 0 rounds
        XCTAssertEqual(label("scoreboard.title"), "未開始")
        XCTAssertTrue(label("scoreboard.empty").contains("未有紀錄"))
        assertBanner("scoreboard-empty")
        snap("scoreboard-empty")

        // Rounds 1–5
        let rounds: [[Int]] = [
            [0, 5, 9, 13],
            [1, 0, 3, 10],
            [2, 12, 0, 8],
            [4, 6, 7, 0],
            [0, 11, 13, 1]
        ]
        for (number, cards) in rounds.enumerated() {
            tap("scoreboard.addRound")
            if number == 0 {
                XCTAssertTrue(label("entry.hint").contains("逐個入剩幾多張"))
                XCTAssertTrue(label("entry.prompt").contains("小肥 剩幾多張？"))
                assertBanner("entry-start")
                snap("entry-start")
                enterRound(cards, snapBeforeLast: "entry-13cards-before-last")
                // Pairwise: penalties 0/5/18/52 → +75 / +55 / +3 / −133; a loser can be positive.
                XCTAssertTrue(label("result.row.2").contains("+3"), label("result.row.2"))
                XCTAssertTrue(label("result.row.0").contains("出晒"), label("result.row.0"))
                XCTAssertFalse(label("result.row.0").contains("收"))
                // Cards ×multiplier per row, all plain (no 炒到盡 / 🔥).
                XCTAssertTrue(label("result.row.3").contains("13 張 ×4"), label("result.row.3"))
                XCTAssertTrue(label("result.row.2").contains("9 張 ×2"), label("result.row.2"))
                XCTAssertFalse(label("result.row.3").contains("炒到盡"))
                XCTAssertFalse(label("result.row.3").contains("🔥"))
                XCTAssertEqual(label("result.totalsHeader"), "累計 · 打咗 1 局")
                // Pairwise breakdown (penalties 0 / 5 / 18 / 52).
                XCTAssertTrue(label("result.row.0").contains("贏呀南 52 張、贏呀權 18 張、贏文仔 5 張"), label("result.row.0"))
                XCTAssertTrue(label("result.row.2").contains("贏呀南 34 張、輸小肥 18 張、輸文仔 13 張"), label("result.row.2"))
                XCTAssertTrue(element("result.undo").label.contains("撤回"))
                XCTAssertFalse(element("result.undo").label.contains("秒"))
                assertBanner("result-round1")
                snap("result-round1")
                // No auto-dismiss: sheet and 撤回 are still there after 4 s.
                XCTAssertFalse(element("result.title").waitForNonExistence(timeout: 4))
                XCTAssertTrue(element("result.undo").exists)
            } else {
                enterRound(cards)
            }
            tapNextRound()
        }
        XCTAssertEqual(label("scoreboard.title"), "打咗 5 局")
        // Pairwise (HK): score_i = P − 4·p_i each round.
        assertTotals(["+238", "−54", "−54", "−130"])
        assertBanner("scoreboard-5-rounds")
        snap("scoreboard-5-rounds")

        // Interstitial stand-in before round 6
        tap("scoreboard.addRound")
        element("interstitial.close", timeout: 10)
        assertNoBanner("interstitial")
        snap("interstitial")
        tap("interstitial.close")

        // Round 6, then undo it from the result screen
        enterRound([13, 0, 2, 9])
        XCTAssertEqual(label("result.title"), "第 6 局結果")
        XCTAssertTrue(element("result.undoToast").label.contains("入錯咗？"))
        XCTAssertEqual(label("result.totalsHeader"), "累計 · 打咗 6 局")
        assertBanner("result-round6-undo-toast")
        snap("result-round6-undo-toast")
        XCTAssertTrue(label("result.row.2").contains("+64"), label("result.row.2"))
        XCTAssertTrue(label("result.row.0").contains("−136"), label("result.row.0"))
        tap("result.undo")
        waitForScoreboard()
        XCTAssertEqual(label("scoreboard.title"), "打咗 5 局")
        assertTotals(["+238", "−54", "−54", "−130"])

        // Round 6 again (no second interstitial), close with 下一局; 撤回 lingers on the scoreboard
        tap("scoreboard.addRound")
        XCTAssertFalse(app.descendants(matching: .any)["interstitial.close"].waitForExistence(timeout: 1.5))
        enterRound([13, 0, 2, 9])
        tapNextRound()
        element("scoreboard.undoToast", timeout: 3)
        snap("scoreboard-undo-toast")
        XCTAssertEqual(label("scoreboard.title"), "打咗 6 局")
        assertTotals(["+102", "+18", "+10", "−130"])

        // History tap shows round 2's result with the pairwise breakdown (penalties 1 / 0 / 3 / 30)
        tap("scoreboard.history.1")
        XCTAssertEqual(label("result.title"), "第 2 局結果")
        XCTAssertTrue(label("result.row.1").contains("贏呀南 30 張、贏呀權 3 張、贏小肥 1 張"), label("result.row.1"))
        XCTAssertTrue(label("result.row.3").contains("輸文仔 30 張、輸小肥 29 張、輸呀權 27 張"), label("result.row.3"))
        XCTAssertFalse(app.descendants(matching: .any)["result.undo"].exists, "no 撤回 when reviewing")
        XCTAssertEqual(label("result.totalsHeader"), "累計 · 打咗 2 局")
        assertBanner("history-round2-breakdown")
        snap("history-round2-breakdown")

        // 編輯 from there: 呀南 10 → 13 cards
        tap("result.edit")
        XCTAssertEqual(label("entry.title"), "第 2 局")
        tap("entry.row.3")
        assertBanner("edit-round2")
        snap("edit-round2")
        tap("pad.13")
        element("result.title")
        tapNextRound()
        assertTotals(["+124", "+40", "+32", "−196"])
        snap("scoreboard-after-edit")

        // 完場 with confirm (cancel first)
        tap("scoreboard.finish")
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        XCTAssertTrue(alert.label.contains("確定完場？") || alert.staticTexts["確定完場？"].exists)
        snap("finish-confirm")
        alert.buttons["取消"].tap()
        XCTAssertTrue(element("scoreboard.finish").exists, "cancel keeps the session open")
        tap("scoreboard.finish")
        app.alerts.firstMatch.buttons["完場"].tap()
        closeFinishInterstitialIfShown()

        // Final
        element("final.title")
        XCTAssertTrue(label("final.rank.1").contains("小肥"))
        XCTAssertTrue(label("final.rank.1").contains("+124"))
        XCTAssertTrue(label("final.rank.4").contains("呀南"))
        XCTAssertTrue(label("final.rank.4").contains("−196"))
        assertBanner("final")
        snap("final")

        // Back home: session in the recent list, 所有紀錄 available
        tap("nav.home")
        element("home.recent.0")
        XCTAssertTrue(label("home.recent.0").contains("6 局"))
        element("home.allSessions")
        assertBanner("home-with-recent")
        snap("home-with-recent")
        tap("home.allSessions")
        element("all.row.0")
        assertBanner("all-sessions")
        snap("all-sessions")
        app.navigationBars.buttons.firstMatch.tap()

        // Settings: no 地區介面 while Taiwan is on hold; 去廣告 stub
        tap("home.settings")
        element("settings.done")
        XCTAssertFalse(app.descendants(matching: .any)["settings.region"].exists)
        assertBanner("settings")
        snap("settings")
        tap("settings.removeAds")
        let removed = element("settings.adsRemoved").label
        XCTAssertTrue(removed.contains("已經移除廣告"), removed)
        assertNoBanner("settings-ads-removed")
        snap("settings-ads-removed")
        tap("settings.done")
        XCTAssertEqual(label("home.title"), "鋤大D計分")
        assertNoBanner("home-ads-removed")
        snap("home-ads-removed")
    }

    // MARK: - zh-TW device while Taiwan is on hold

    func testTaiwanDeviceFallsBackToHongKong() {
        launch(languages: "zh-Hant-TW", locale: "zh_TW", prefix: "HK-on-zhTW")
        XCTAssertEqual(label("home.title"), "鋤大D計分")
        tap("home.newSession")
        assertText("新開一場")
        XCTAssertEqual(element("setup.tile.8").value as? String, "×2", "HK 炒法 default")
        assertBanner("setup")
        snap("setup")
        tap("setup.close")
        tap("home.settings")
        element("settings.done")
        XCTAssertFalse(app.descendants(matching: .any)["settings.region"].exists)
        assertBanner("settings")
        snap("settings")
    }

    // MARK: - Taiwan, flag forced on (non-blocking in CI while Taiwan is on hold)

    func testTaiwanFlowFlagForcedOn() {
        launch(languages: "zh-Hant-TW", locale: "zh_TW", prefix: "TW", extra: ["-enableTaiwan"])

        XCTAssertEqual(label("home.title"), "大老二記分")
        assertBanner("home-fresh")
        snap("home-fresh")

        tap("home.newSession")
        assertText("開新牌局")
        XCTAssertEqual(element("setup.tile.8").value as? String, "×1")
        XCTAssertEqual(element("setup.tile.10").value as? String, "×2")
        XCTAssertEqual(element("setup.tile.13").value as? String, "×3")
        XCTAssertTrue(element("setup.namesHint").label.contains("請填寫 4 位玩家名稱"))
        assertBanner("setup-empty")
        snap("setup-empty")
        typeNames(["小明", "阿強", "小美", "志明"])
        snap("setup-filled")
        tap("setup.start")

        XCTAssertEqual(label("scoreboard.title"), "尚未開局")
        XCTAssertTrue(label("scoreboard.empty").contains("還沒有紀錄"))
        assertBanner("scoreboard-empty")
        snap("scoreboard-empty")

        tap("scoreboard.addRound")
        XCTAssertTrue(label("entry.hint").contains("依序輸入剩幾張"))
        XCTAssertTrue(label("entry.prompt").contains("小明 剩幾張？"))
        assertBanner("entry-start")
        snap("entry-start")
        tap("pad.13")
        XCTAssertTrue(label("entry.row.0").contains("×3"), label("entry.row.0"))
        XCTAssertFalse(label("entry.row.0").contains("最高"))
        tap("pad.win")
        XCTAssertFalse(element("pad.win").isEnabled, "only one winner")
        tap("pad.10")
        snap("entry-before-last")
        tap("pad.5")
        element("result.title")
        XCTAssertTrue(element("result.undoToast").label.contains("輸入錯誤？"))
        XCTAssertTrue(label("result.row.0").contains("13 張 ×3"), label("result.row.0"))
        XCTAssertFalse(label("result.row.0").contains("最高"))
        XCTAssertEqual(label("result.totalsHeader"), "累計 · 已進行 1 局")
        assertBanner("result")
        snap("result")
        tapNextRound()
        // 13×3 + 10×2 + 5 = 64 to 阿強
        assertTotals(["−39", "+64", "−20", "−5"])
        XCTAssertEqual(label("scoreboard.title"), "已進行 1 局")
        assertBanner("scoreboard-1-round")
        snap("scoreboard-1-round")

        tap("scoreboard.finish")
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        snap("finish-confirm")
        alert.buttons["結束"].tap()
        // First ad of this session, 1 round played → the 完場 interstitial shows.
        element("interstitial.close")
        assertNoBanner("finish-interstitial")
        snap("finish-interstitial")
        tap("interstitial.close")
        element("final.title")
        XCTAssertTrue(label("final.rank.1").contains("阿強"))
        assertBanner("final")
        snap("final")
        tap("nav.home")
        element("home.recent.0")
        assertBanner("home-with-recent")
        snap("home-with-recent")
    }
}
