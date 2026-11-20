import XCTest

/// Build 77/79 「入名 / 入分 / 切換外觀 freeze 幾秒然後閃退」: plays several rounds and switches
/// skins back and forth, timing every step. A main-thread hang shows up as a step that takes
/// far longer than usual (XCUITest waits for the app to go idle after each tap).
/// Runs in HK (`Big2UITests`) and TW (`DaLaoErUITests`). With `HANG_TEST_REAL_ADS=1` the real
/// Google SDK (test units) loads banners, like TestFlight.
final class HangUITests: XCTestCase {
    private var app: XCUIApplication!
    private var timings: [String] = []

    private var isTaiwan: Bool {
        Bundle(for: HangUITests.self).bundleIdentifier?.contains("dalaoer") == true
    }

    private var realAds: Bool {
        ProcessInfo.processInfo.environment["HANG_TEST_REAL_ADS"] == "1"
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
        let tag = "\(isTaiwan ? "DLE" : "HK")-HANG-\(skin)\(realAds ? "-realads" : "")"

        // Give the real banner time to load (TestFlight shows a real test ad).
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

    private func timed(_ step: String, _ body: () -> Void) {
        let start = Date()
        body()
        let elapsed = Date().timeIntervalSince(start)
        timings.append(String(format: "%6.2fs  %@", elapsed, step))
        XCTAssertEqual(app.state, .runningForeground, "app not running after: \(step)")
        XCTAssertLessThan(elapsed, maxStep, "UI hang: \(step) took \(elapsed)s")
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
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for label in ["Ask App Not to Track", "要求 App 不要追蹤", "Allow", "允許"] {
            let button = springboard.buttons[label]
            if button.waitForExistence(timeout: label == "Ask App Not to Track" ? wait : 0.5) {
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

    private func tap(_ id: String, file: StaticString = #filePath, line: UInt = #line) {
        let target = element(id, file: file, line: line)
        let deadline = Date().addingTimeInterval(10)
        while !target.isHittable && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        timed("tap \(id)") { target.tap() }
    }

    private func snap(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
