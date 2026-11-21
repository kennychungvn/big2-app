import XCTest

/// 2.0 build 77 「入名有閃退」: drives every name-entry path (typing CJK / emoji / long
/// names, return-key navigation, ✕, 清除全部, prefill, quick-fill chips, long-press delete,
/// 管理快速填入名稱) in both skins. Runs in HK (`Big2UITests`) and TW (`DaLaoErUITests`).
/// CI also runs it against a Release build, and with the real Google SDK (test ads) when
/// the runner sets `TEST_RUNNER_NAME_TEST_REAL_ADS=1`.
final class NameEntryUITests: XCTestCase {
    private var app: XCUIApplication!

    private var isTaiwan: Bool {
        Bundle(for: NameEntryUITests.self).bundleIdentifier?.contains("dalaoer") == true
    }

    private var realAds: Bool {
        ProcessInfo.processInfo.environment["NAME_TEST_REAL_ADS"] == "1"
    }

    override func setUp() {
        continueAfterFailure = false
    }

    func testNameEntryClassic() { runNameEntry(skin: "classic") }
    func testNameEntryLedger() { runNameEntry(skin: "ledger") }

    // MARK: - Flow

    private func runNameEntry(skin: String) {
        app = XCUIApplication()
        var args = [
            "-uiTesting",
            "-AppleLanguages", isTaiwan ? "(zh-Hant-TW)" : "(zh-Hant-HK)",
            "-AppleLocale", isTaiwan ? "zh_TW" : "zh_HK",
            "-skin", skin,
        ]
        if !realAds { args.append("-uiTestAds") }
        app.launchArguments = args
        app.launch()
        dismissSystemAlerts()
        let tag = "\(isTaiwan ? "DLE" : "HK")-NAME-\(skin)\(realAds ? "-realads" : "")"

        // 1. Fresh sheet: type four names with the return key, CJK + emoji + a long one.
        tap("home.newSession")
        element("setup.name.0")
        dismissSystemAlerts()
        typeInto(0, "小肥")
        typeInto(1, "文仔", submit: false)
        app.typeText("\n")
        typeInto(2, "阿強😀")
        typeInto(3, "一個非常非常非常非常非常長嘅名字 Kenny Chung")
        assertAlive("typed four names")
        snap("\(tag)-01-typed")

        // 2. ✕ on one field, retype; 清除全部, retype.
        tap("setup.name.clear.1")
        assertAlive("✕")
        typeInto(1, "Ken")
        tap("setup.clearAll")
        assertAlive("清除全部")
        typeInto(0, "小明")
        typeInto(1, "阿強")
        typeInto(2, "小美")
        typeInto(3, "志明")
        snap("\(tag)-02-retyped")

        // 3. Start, go home, open the sheet again: prefilled names.
        tap("setup.start")
        element("scoreboard.addRound")
        tap("nav.home")
        tap("home.newSession")
        element("setup.name.0")
        assertAlive("prefilled sheet")
        snap("\(tag)-03-prefilled")

        // 4. Edit a prefilled name (select-all on focus), then 清除全部 → quick-fill chips.
        typeInto(2, "新名")
        tap("setup.clearAll")
        for name in ["小明", "阿強", "志明"] {
            let chip = app.descendants(matching: .any)["setup.chip.\(name)"].firstMatch
            if chip.waitForExistence(timeout: 5) { chip.tap() }
            assertAlive("chip \(name)")
        }
        snap("\(tag)-04-chips")

        // 5. Long-press a chip → 刪除 (context menu).
        let chip = app.descendants(matching: .any)["setup.chip.小美"].firstMatch
        if chip.waitForExistence(timeout: 5) {
            chip.press(forDuration: 1.2)
            let delete = app.buttons["刪除"].firstMatch
            if delete.waitForExistence(timeout: 5) { delete.tap() }
            assertAlive("chip delete")
        }
        typeInto(3, "Ken")
        snap("\(tag)-05-after-chip-delete")
        tap("setup.start")
        element("scoreboard.addRound")

        // 6. Settings → 管理快速填入名稱.
        tap("nav.home")
        tap("home.settings")
        element("settings.done")
        // TW Settings inserts 計分方式 and 加倍門檻 above 體驗, so the
        // 管理快速填入名稱 row may not be in a virtualized List yet.
        // Scroll until it exists, then until it is hittable.
        let manage = reveal("settings.knownNames")
        manage.tap()
        assertAlive("known names")
        snap("\(tag)-06-known-names")
    }

    // MARK: - Helpers

    private func typeInto(_ index: Int, _ text: String, submit: Bool = true) {
        let field = element("setup.name.\(index)")
        focus(field)
        let clear = app.descendants(matching: .any)["setup.name.clear.\(index)"].firstMatch
        if clear.exists, clear.isHittable {
            clear.tap()
            focus(field)
        }
        field.typeText(submit ? text + "\n" : text)
        assertAlive("typing field \(index)")
    }

    private func focus(_ field: XCUIElement) {
        for _ in 1...3 {
            field.tap()
            let deadline = Date().addingTimeInterval(10)
            while Date() < deadline {
                if (field.value(forKey: "hasKeyboardFocus") as? Bool) == true { return }
                RunLoop.current.run(until: Date().addingTimeInterval(0.2))
            }
        }
    }

    /// ATT / UMP alerts only appear with the real SDK.
    private func dismissSystemAlerts() {
        guard realAds else { return }
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for label in ["Ask App Not to Track", "要求 App 不要追蹤", "Allow", "允許"] {
            let button = springboard.buttons[label]
            if button.waitForExistence(timeout: label == "Ask App Not to Track" ? 12 : 1) {
                button.tap()
                return
            }
        }
    }

    private func assertAlive(_ step: String, file: StaticString = #filePath, line: UInt = #line) {
        RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        XCTAssertEqual(app.state, .runningForeground, "app not running after: \(step)", file: file, line: line)
    }

    private func element(_ id: String, timeout: TimeInterval = 15, file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let element = app.descendants(matching: .any)[id].firstMatch
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "missing \(id) (app state \(app.state.rawValue))", file: file, line: line)
        return element
    }

    /// Scroll a Settings list until `id` is in the hierarchy (and then hittable).
    /// Waiting first fails on TW when the row has not been materialized yet.
    private func reveal(_ id: String, timeout: TimeInterval = 15, file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let target = app.descendants(matching: .any)[id].firstMatch
        let deadline = Date().addingTimeInterval(timeout)
        while !target.exists && Date() < deadline {
            app.swipeUp()
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        XCTAssertTrue(target.waitForExistence(timeout: 2), "missing \(id) (app state \(app.state.rawValue))", file: file, line: line)
        while !target.isHittable && Date() < deadline {
            app.swipeUp()
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        return target
    }

    private func tap(_ id: String, file: StaticString = #filePath, line: UInt = #line) {
        let target = element(id, file: file, line: line)
        let deadline = Date().addingTimeInterval(10)
        while !target.isHittable && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        target.tap()
        assertAlive("tap \(id)", file: file, line: line)
    }

    private func snap(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
