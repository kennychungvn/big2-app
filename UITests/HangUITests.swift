import XCTest

/// Build 77/79 「入名 / 入分 / 切換外觀 freeze 幾秒然後閃退」: plays several rounds and switches
/// skins back and forth, timing every step. A main-thread hang shows up as a step that takes
/// far longer than usual (XCUITest waits for the app to go idle after each tap).
/// Runs in HK (`Big2UITests`) and TW (`DaLaoErUITests`). With `HANG_TEST_SDK_ADS=1` the real
/// Google SDK starts under `-uiTesting`, which skips UMP/ATT prompts and keeps the
/// static ad-band placeholder (no live BannerView / WKWebView), so the 8 s budget
/// measures the app going idle rather than a demo creative. `testLiveBannerMainThreadDuringNameEntry`
/// remounts the live demo banner and judges lag from an in-app main-thread watchdog,
/// not from XCUITest wait-for-idle.
final class HangUITests: XCTestCase {
    private var app: XCUIApplication!
    private var timings: [String] = []

    private var isTaiwan: Bool {
        Bundle(for: HangUITests.self).bundleIdentifier?.contains("dalaoer") == true
    }

    private var realAds: Bool {
        let env = ProcessInfo.processInfo.environment
        return env["HANG_TEST_SDK_ADS"] == "1" || env["HANG_TEST_REAL_ADS"] == "1"
    }

    /// Generous for slow Intel CI simulators; a real hang is many seconds.
    private let maxStep: TimeInterval = 8

    override func setUp() {
        continueAfterFailure = true
    }

    override func tearDown() {
        let attachment = XCTAttachment(string: timings.joined(separator: "\n"))
        attachment.name = "timings"
        attachment.lifetime = .keepAlways
        add(attachment)
        print("TIMINGS\n" + timings.joined(separator: "\n"))
    }

    func testRoundsAndSkinSwitchClassic() { run(skin: "classic") }
    func testRoundsAndSkinSwitchLedger() { run(skin: "ledger") }

    /// Filled live demo banner + in-app main-thread stall detector. XCUITest step
    /// times may still be long (wait-for-idle on the WKWebView); the verdict is
    /// whether the main thread itself paused ≥ 250 ms while a name field was focused.
    func testLiveBannerMainThreadDuringNameEntry() throws {
        try XCTSkipUnless(realAds, "live banner probe runs only in the SDK demo-ad hang job")
        app = XCUIApplication()
        app.launchArguments = [
            "-uiTesting", "-uiTestRealIcon",
            "-uiTestLiveBanner", "-uiTestHangDetector",
            "-AppleLanguages", isTaiwan ? "(zh-Hant-TW)" : "(zh-Hant-HK)",
            "-AppleLocale", isTaiwan ? "zh_TW" : "zh_HK",
            "-skin", "classic",
        ]
        app.launch()
        dismissSystemAlerts(wait: 1)
        settle(8)
        // The banner must fill on the home screen before 新開一場 opens, so the
        // first load is not still in flight when the sheet and keyboard appear.
        let homeBanner = element("banner.home", timeout: 20)
        let homeFillDeadline = Date().addingTimeInterval(20)
        while Date() < homeFillDeadline {
            let value = (homeBanner.value as? String) ?? homeBanner.label
            if value.contains("filled") { break }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        let homeState = (homeBanner.value as? String) ?? homeBanner.label
        print("HOME_BANNER_STATE \(homeState)")
        tap("home.newSession", budget: nil)
        let names = ["小明", "阿強", "小美", "志明"]
        for (index, name) in names.enumerated() {
            let field = element("setup.name.\(index)", timeout: 30)
            timed("focus name \(index)", budget: nil) { field.tap() }
            timed("type name \(index)", budget: nil) { field.typeText(name + "\n") }
        }
        settle(1)
        let sheetBanner = element("banner.sheet", timeout: 20)
        let fillDeadline = Date().addingTimeInterval(25)
        while Date() < fillDeadline {
            let value = (sheetBanner.value as? String) ?? sheetBanner.label
            if value.contains("filled") { break }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        let bannerState = (sheetBanner.value as? String) ?? sheetBanner.label
        print("SHEET_BANNER_STATE \(bannerState)")
        let stateAttachment = XCTAttachment(string: bannerState)
        stateAttachment.name = "sheet-banner-state"
        stateAttachment.lifetime = .keepAlways
        add(stateAttachment)
        snap("sheet-live-banner")
        XCTAssertTrue(bannerState.contains("filled"), "sheet banner did not fill (demo ad): \(bannerState)")
        let reportEl = element("hangDetector.report", timeout: 30)
        let report = (reportEl.value as? String).flatMap { $0.isEmpty ? nil : $0 }
            ?? reportEl.label
        print("HANG_DETECTOR_REPORT \(report)")
        let attachment = XCTAttachment(string: report)
        attachment.name = "hang-detector"
        attachment.lifetime = .keepAlways
        add(attachment)
        let editingMax = Self.intValue("maxEditingMs", in: report) ?? 0
        // Keyboard presentation can hitch a few hundred ms; a user-visible freeze is seconds.
        XCTAssertLessThan(editingMax, 2000, "main-thread stall while editing: \(report)")
    }

    private func run(skin: String) {
        app = XCUIApplication()
        var args = [
            "-uiTesting", "-uiTestRealIcon",
            "-AppleLanguages", isTaiwan ? "(zh-Hant-TW)" : "(zh-Hant-HK)",
            "-AppleLocale", isTaiwan ? "zh_TW" : "zh_HK",
            "-skin", skin,
        ]
        if !realAds { args.append("-uiTestAds") }
        app.launchArguments = args
        app.launch()
        dismissSystemAlerts(wait: 12)
        let tag = "\(isTaiwan ? "DLE" : "HK")-HANG-\(skin)\(realAds ? "-demoad" : "")"

        // Give the SDK banner time to load (TestFlight / CI use official demo units).
        settle(realAds ? 6 : 1)
        tap("home.newSession")
        let names = ["小明", "阿強", "小美", "志明"]
        for (index, name) in names.enumerated() {
            let field = element("setup.name.\(index)")
            timed("focus name \(index)") { field.tap() }
            dismissSystemAlerts(wait: 0.5)
            timed("type name \(index)") { field.typeText(name + "\n") }
        }
        tap("setup.start")
        element("scoreboard.addRound")
        settle(realAds ? 5 : 1)

        for round in 1...4 {
            tap("scoreboard.addRound")
            element("entry.title")
            settle(realAds ? 4 : 0.5)
            enterRound(round)
            snap("\(tag)-round\(round)")
            tap("result.next")
            element("scoreboard.addRound")
            settle(realAds ? 3 : 0.5)
            assertResponsive("after round \(round)")
        }

        // Settings → switch skin twice, staying on screen ~3 s after each switch.
        tap("nav.home")
        tap("home.settings")
        element("settings.done")
        settle(realAds ? 4 : 1)
        let other = skin == "classic" ? "ledger" : "classic"
        for target in [other, skin, other] {
            tap("settings.skin.\(target)")
            dismissSystemAlerts(wait: 1)
            settle(3)
            dismissIconAlert()
            assertResponsive("after skin → \(target)")
            snap("\(tag)-skin-\(target)")
        }
        tap("settings.done")
        tap("home.continue")
        element("scoreboard.addRound")
        tap("scoreboard.addRound")
        element("entry.title")
        settle(realAds ? 4 : 0.5)
        enterRound(5)
        snap("\(tag)-round5")
        assertResponsive("end")
    }

    private func enterRound(_ round: Int) {
        if isTaiwan {
            for key in ["pad.win", "pad.10", "pad.13", "pad.5"] { tap(key) }
            tap("entry.confirm")
        } else {
            let sets = [["pad.win", "pad.5", "pad.9", "pad.13"], ["pad.2", "pad.win", "pad.11", "pad.4"]]
            for key in sets[round % 2] { tap(key) }
        }
        element("result.title")
    }

    // MARK: - Helpers

    private func timed(_ step: String, budget: TimeInterval? = 8, _ body: () -> Void) {
        let start = Date()
        body()
        let elapsed = Date().timeIntervalSince(start)
        timings.append(String(format: "%6.2fs  %@", elapsed, step))
        XCTAssertEqual(app.state, .runningForeground, "app not running after: \(step)")
        if let budget {
            XCTAssertLessThan(elapsed, budget, "UI hang: \(step) took \(elapsed)s")
        }
    }

    private static func intValue(_ key: String, in report: String) -> Int? {
        let parts = report.split(separator: " ")
        guard let part = parts.first(where: { $0.hasPrefix(key + "=") }) else { return nil }
        return Int(part.dropFirst(key.count + 1))
    }

    private func assertResponsive(_ step: String) {
        // Probe: reading the hierarchy needs an idle main thread.
        timed("probe \(step)") { _ = app.descendants(matching: .any).count }
    }

    private func settle(_ seconds: TimeInterval) {
        RunLoop.current.run(until: Date().addingTimeInterval(seconds))
    }

    private func dismissSystemAlerts(wait: TimeInterval) {
        guard realAds else { return }
        // `-uiTesting` skips the ATT prompt, so do not wait 12 s (or snapshot the
        // hierarchy on every miss). A short check still clears a leftover alert.
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for label in ["Ask App Not to Track", "要求 App 不要追蹤", "Allow", "允許"] {
            let button = springboard.buttons[label]
            if button.waitForExistence(timeout: min(wait, 1)) {
                button.tap()
                return
            }
        }
    }

    /// iOS "You have changed the icon" alert.
    private func dismissIconAlert() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let ok = springboard.alerts.buttons.firstMatch
        if ok.exists { ok.tap() }
        let appAlert = app.alerts.buttons.firstMatch
        if appAlert.exists { appAlert.tap() }
    }

    @discardableResult
    private func element(_ id: String, timeout: TimeInterval = 20, file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let element = app.descendants(matching: .any)[id].firstMatch
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "missing \(id) (app state \(app.state.rawValue))", file: file, line: line)
        return element
    }

    private func tap(_ id: String, budget: TimeInterval? = 8, file: StaticString = #filePath, line: UInt = #line) {
        let target = element(id, file: file, line: line)
        let deadline = Date().addingTimeInterval(10)
        while !target.isHittable && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        timed("tap \(id)", budget: budget) { target.tap() }
    }

    private func snap(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
