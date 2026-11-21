import XCTest

/// Design sign-off stills for the 2.0 names-delete polish and (later) the empty home.
/// Screenshot names must match the CI export regex: `(HK|TW|DLE)[-A-Za-z0-9]+`.
/// HK stills land in the `ui-screenshots` artifact; DaLaoEr stills in `ui-screenshots-taiwan`.
final class SignOffUITests: XCTestCase {
    private var app: XCUIApplication!

    private var isTaiwan: Bool {
        Bundle(for: SignOffUITests.self).bundleIdentifier?.contains("dalaoer") == true
    }

    private var prefix: String { isTaiwan ? "DLE" : "HK" }

    override func setUp() {
        continueAfterFailure = false
    }

    func testSignOffNamesDeleteClassic() { runNamesDelete(skin: "classic") }
    func testSignOffNamesDeleteLedger() { runNamesDelete(skin: "ledger") }

    // MARK: - 管理快速填入名稱, 編輯 mode

    private func runNamesDelete(skin: String) {
        launch(skin: skin, knownNames: "A,B,C,D")
        openKnownNamesEditor()

        // Mid-row 刪除 open (B), minus and name stay visible on the left.
        tap("settings.knownNames.minus.B")
        let deleteB = element("settings.knownNames.delete.B")
        waitUntil { deleteB.isHittable }
        snap("\(prefix)-SIGNOFF-\(skin)-names-delete-mid")

        // Deleting B must leave C closed (keyed by name, not row index).
        deleteB.tap()
        waitGone("settings.knownNames.minus.B")
        let deleteC = app.descendants(matching: .any)["settings.knownNames.delete.C"].firstMatch
        waitUntil { !deleteC.exists || !deleteC.isHittable }
        XCTAssertFalse(deleteC.exists && deleteC.isHittable, "C opened 刪除 after deleting B")
        element("settings.knownNames.minus.C")
        snap("\(prefix)-SIGNOFF-\(skin)-names-delete-after")

        // Last row (D, after B was removed: A, C, D) with 刪除 inside the rounded corner.
        tap("settings.knownNames.minus.D")
        let deleteD = element("settings.knownNames.delete.D")
        waitUntil { deleteD.isHittable }
        snap("\(prefix)-SIGNOFF-\(skin)-names-delete-last")

        app.terminate()
    }

    // MARK: - Launch / navigation

    private func launch(skin: String, knownNames: String?) {
        app = XCUIApplication()
        var args = [
            "-uiTesting", "-uiTestAds",
            "-AppleLanguages", isTaiwan ? "(zh-Hant-TW)" : "(zh-Hant-HK)",
            "-AppleLocale", isTaiwan ? "zh_TW" : "zh_HK",
            "-skin", skin,
        ]
        if let knownNames {
            args += ["-uiTestKnownNames", knownNames]
        }
        app.launchArguments = args
        app.launch()
        element("home.title")
    }

    private func openKnownNamesEditor() {
        tap("home.settings")
        element("settings.done")
        let manage = reveal("settings.knownNames")
        manage.tap()
        element("settings.knownName.0")
        tap("settings.knownNames.edit")
        element("settings.knownNames.minus.A")
        // Let the edit-mode rows settle before opening 刪除.
        RunLoop.current.run(until: Date().addingTimeInterval(0.3))
    }

    // MARK: - Helpers

    private func snap(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @discardableResult
    private func element(_ id: String, timeout: TimeInterval = 15, file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
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

    /// Scroll a Settings list until `id` is in the hierarchy and hittable (TW inserts
    /// extra rows above 體驗, so the link may not be materialized yet).
    private func reveal(_ id: String, timeout: TimeInterval = 15, file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let target = app.descendants(matching: .any)[id].firstMatch
        let deadline = Date().addingTimeInterval(timeout)
        while !target.exists && Date() < deadline {
            app.swipeUp()
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        XCTAssertTrue(target.waitForExistence(timeout: 2), "missing \(id)", file: file, line: line)
        while !target.isHittable && Date() < deadline {
            app.swipeUp()
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        return target
    }
}
