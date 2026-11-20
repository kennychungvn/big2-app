import XCTest

/// Screenshots and a smoke path for the Taiwan-only 大老二計分 target (`DaLaoEr`).
/// Launch arguments match the Hong Kong UI tests so ads are stubbed and data starts empty.
final class DaLaoErUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = [
            "-uiTesting", "-uiTestAds",
            "-AppleLanguages", "(zh-Hant-TW)",
            "-AppleLocale", "zh_TW",
        ]
        app.launch()
    }

    func testTaiwanAppSetupEntrySettlement() {
        element("home.title")
        XCTAssertEqual(label("home.title"), "大老二計分")
        assertNoHongKongWording(on: "home")
        tap("home.newSession")

        element("setup.name.0")
        XCTAssertTrue(text("開新牌局").exists)
        XCTAssertTrue(element("setup.mode.winnerTakesAll").exists)
        XCTAssertTrue(element("setup.mode.pairwise").exists)
        assertText("贏家通吃")
        assertText("互對")
        assertText("加倍門檻")
        assertNoHongKongWording(on: "setup")
        typeNames(["小明", "阿強", "小美", "志明"])
        snap("DLE-01-setup")

        tap("setup.start")
        element("scoreboard.addRound")
        tap("scoreboard.addRound")
        element("entry.title")

        tap("pad.win")
        tap("pad.10")
        tap("pad.13")
        tap("pad.5")
        element("entry.double.inc.1")
        tap("entry.double.inc.1")
        tap("entry.double.inc.2")
        tap("entry.double.inc.2")
        element("entry.total")
        XCTAssertTrue(label("entry.total").contains("273") || app.staticTexts["273"].exists)
        assertText("本局合計")
        assertText("贏家通吃")
        assertNoHongKongWording(on: "entry")
        snap("DLE-02-entry")

        tap("entry.confirm")
        element("result.title")
        assertText("273")
        assertNoHongKongWording(on: "settlement")
        snap("DLE-03-settlement")
    }

    // MARK: - Helpers

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

    private func waitUntil(timeout: TimeInterval = 10, file: StaticString = #filePath, line: UInt = #line, _ condition: () -> Bool) {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        XCTFail("condition not met in \(timeout)s", file: file, line: line)
    }

    private func label(_ id: String) -> String {
        element(id).label
    }

    private func text(_ fragment: String) -> XCUIElement {
        app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", fragment)).firstMatch
    }

    private func assertText(_ fragment: String, file: StaticString = #filePath, line: UInt = #line) {
        let predicate = NSPredicate(format: "label CONTAINS %@", fragment)
        let match = app.descendants(matching: .any).matching(predicate).firstMatch
        XCTAssertTrue(match.waitForExistence(timeout: 10), "text not found: \(fragment)", file: file, line: line)
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

    /// Forbidden Hong Kong / mixed wording that must never appear in the Taiwan app.
    private func assertNoHongKongWording(on screen: String) {
        let forbidden = ["鋤大D", "鋤大 Dee", "炒法", "炒倍", "開波", "香港玩法", "出晒", "通食", "新開一場"]
        let snapshot = app.debugDescription
        for word in forbidden {
            XCTAssertFalse(snapshot.contains(word), "HK wording “\(word)” appeared on \(screen)")
        }
    }
}
