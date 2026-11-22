import XCTest

/// Marketing stills for App Store 2.0 screenshots (經典, no test-ads banner).
/// Runs on the `appstore-stills` branch; not part of the build-113 / v2.0 product line.
final class AppStoreStillsUITests: XCTestCase {
    private var app: XCUIApplication!

    private var isTaiwan: Bool {
        Bundle(for: AppStoreStillsUITests.self).bundleIdentifier?.contains("dalaoer") == true
    }

    private var displayNames: [String] {
        isTaiwan ? ["小明", "阿哲", "小美", "大偉"] : ["阿明", "阿軒", "阿玲", "阿俊"]
    }

    override func setUp() {
        continueAfterFailure = false
    }

    /// New Game after tapping all four 快速填入 chips: no red validation line, no
    /// leftover chips overlapping the 炒 / 加倍 tiles.
    func testNamesQuickFill() {
        launch(knownNames: displayNames)
        tap("home.newSession")
        element("setup.name.0")
        for name in displayNames {
            tap("setup.chip.\(name)")
        }
        for name in displayNames {
            let chip = app.descendants(matching: .any)["setup.chip.\(name)"].firstMatch
            XCTAssertFalse(chip.exists, "chip \(name) should be consumed")
        }
        let hint = app.descendants(matching: .any)["setup.namesHint"].firstMatch
        XCTAssertFalse(hint.exists, "red names hint should be gone once all 4 names are filled")
        XCTAssertTrue(element("setup.start").isEnabled)
        dismissKeyboard()
        let tile = element("setup.tile.8")
        XCTAssertTrue(tile.isHittable, "炒 / 加倍 tile should be visible and not overlapped")
        for (index, name) in displayNames.enumerated() {
            let field = element("setup.name.\(index)")
            let value = (field.value as? String) ?? field.label
            XCTAssertTrue(value.contains(name), "seat \(index): \(value) ≠ \(name)")
        }
        RunLoop.current.run(until: Date().addingTimeInterval(0.4))
        snap(isTaiwan ? "DLE-names-quickfill" : "HK-names-quickfill")
    }

    /// TW 完場 / 最終排名 with 換算 on, keypad dismissed, converted totals visible.
    func testSettleConvert() throws {
        try XCTSkipUnless(isTaiwan, "settle_convert still is for the DaLaoEr target only")
        launch(knownNames: nil)
        tap("home.newSession")
        element("setup.name.0")
        typeNames(displayNames)
        dismissKeyboard()
        tap("setup.start")
        tap("scoreboard.addRound")
        element("entry.title")
        tap("pad.win")
        tap("pad.10")
        tap("pad.13")
        tap("pad.5")
        tapVisible("entry.double.inc.1")
        tapVisible("entry.double.inc.2")
        tapVisible("entry.double.inc.2")
        element("entry.total")
        tap("entry.confirm")
        element("result.title")
        tap("result.next")
        element("scoreboard.finish")
        tap("scoreboard.finish")
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "missing 完場 confirm")
        let confirm = alert.buttons["結束"].firstMatch.exists ? alert.buttons["結束"] : alert.buttons["完場"]
        confirm.tap()
        let close = app.descendants(matching: .any)["interstitial.close"].firstMatch
        if close.waitForExistence(timeout: 4) { close.tap() }
        element("final.title")
        RunLoop.current.run(until: Date().addingTimeInterval(1.2))
        tap("final.conversion")
        let field = element("final.conversion.field")
        typeNumberPadDigit("5", into: field)
        XCTAssertTrue(label("final.conversion").contains("換算 ×5"), label("final.conversion"))
        XCTAssertTrue(label("final.rank.1").contains("×5"), label("final.rank.1"))
        let conversion = element("final.conversion")
        if conversion.isHittable {
            conversion.tap()
        } else {
            app.navigationBars.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
        waitGone("final.conversion.field")
        XCTAssertTrue(label("final.conversion").contains("換算 ×5"), label("final.conversion"))
        XCTAssertTrue(label("final.rank.1").contains("×5"), label("final.rank.1"))
        RunLoop.current.run(until: Date().addingTimeInterval(0.6))
        snap("DLE-settle-convert")
    }

    // MARK: - Helpers

    private func launch(knownNames: [String]?) {
        app = XCUIApplication()
        var args = [
            "-uiTesting", "-uiTestAds", "-uiTestHideBanner",
            "-AppleLanguages", isTaiwan ? "(zh-Hant-TW)" : "(zh-Hant-HK)",
            "-AppleLocale", isTaiwan ? "zh_TW" : "zh_HK",
            "-skin", "classic",
        ]
        if let knownNames {
            args += ["-uiTestKnownNames", knownNames.joined(separator: ",")]
        }
        app.launchArguments = args
        app.launch()
    }

    private func snap(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
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

    private func tapVisible(_ id: String, file: StaticString = #filePath, line: UInt = #line) {
        let target = element(id, file: file, line: line)
        if !target.isHittable {
            app.swipeUp()
        }
        waitUntil(timeout: 12, file: file, line: line) {
            if target.isHittable { return true }
            app.swipeUp()
            return target.isHittable
        }
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

    private func dismissKeyboard() {
        if app.keyboards.firstMatch.exists {
            let titles = isTaiwan ? ["加倍門檻", "計分方式"] : ["炒法"]
            var dismissed = false
            for title in titles {
                let label = app.staticTexts[title].firstMatch
                if label.exists, label.isHittable {
                    label.tap()
                    dismissed = true
                    break
                }
            }
            if !dismissed {
                app.navigationBars.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            }
            waitUntil(timeout: 5) { !app.keyboards.firstMatch.exists }
        }
    }

    private func typeNames(_ names: [String]) {
        for (index, name) in names.enumerated() {
            let field = element("setup.name.\(index)")
            focusNameField(field)
            let clear = app.descendants(matching: .any)["setup.name.clear.\(index)"].firstMatch
            if clear.exists, clear.isHittable {
                clear.tap()
                focusNameField(field)
            }
            field.typeText(name + "\n")
        }
    }

    private func focusNameField(_ field: XCUIElement) {
        for _ in 1...3 {
            field.tap()
            if hasKeyboardFocus(field, timeout: 20) { return }
        }
    }

    private func hasKeyboardFocus(_ field: XCUIElement, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if (field.value(forKey: "hasKeyboardFocus") as? Bool) == true { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        return false
    }

    private func typeNumberPadDigit(_ digit: String, into field: XCUIElement) {
        if !hasKeyboardFocus(field, timeout: 5) {
            field.tap()
            _ = hasKeyboardFocus(field, timeout: 5)
        }
        let key = app.keyboards.keys[digit].firstMatch
        XCTAssertTrue(key.waitForExistence(timeout: 8), "number pad key \(digit) not found")
        waitUntil { key.isHittable }
        key.tap()
    }
}
