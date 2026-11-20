import XCTest

/// Baseline comparison (1.0.2 vs 2.0): name entry only, Release + real ads, same timing
/// method as HangUITests. NAME_SET=cjk types 小明…, NAME_SET=ascii types Ming….
final class NameHangUITests: XCTestCase {
    private var app: XCUIApplication!
    private var timings: [String] = []

    override func setUp() { continueAfterFailure = true }

    override func tearDown() {
        print("TIMINGS\n" + timings.joined(separator: "\n"))
    }

    func testNameEntryTwice() {
        let ascii = ProcessInfo.processInfo.environment["NAME_SET"] == "ascii"
        let names = ascii ? ["Ming", "Keung", "Mei", "Chi"] : ["小明", "阿強", "小美", "志明"]
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-AppleLanguages", "(zh-Hant-HK)", "-AppleLocale", "zh_HK"]
        app.launch()
        dismissSystemAlerts(wait: 12)
        settle(6)
        for pass in 0..<2 {
            tap("home.newSession")
            settle(2)
            for (index, name) in names.enumerated() {
                let field = element("setup.name.\(index)")
                if pass == 1 {
                    timed("p\(pass) clear \(index)") { tapIfExists("setup.name.clear.\(index)") }
                }
                timed("p\(pass) focus name \(index)") { field.tap() }
                dismissSystemAlerts(wait: 0.5)
                timed("p\(pass) type name \(index)") { field.typeText(name) }
                timed("p\(pass) return \(index)") { field.typeText("\n") }
            }
            timed("p\(pass) probe") { _ = app.descendants(matching: .any).count }
            tap("setup.close")
            settle(2)
        }
    }

    private func timed(_ step: String, _ body: () -> Void) {
        let start = Date()
        body()
        let elapsed = Date().timeIntervalSince(start)
        timings.append(String(format: "%6.2fs  %@", elapsed, step))
        print(String(format: "STEP %6.2fs  %@", elapsed, step))
        XCTAssertEqual(app.state, .runningForeground, "app not running after: \(step)")
    }

    private func settle(_ s: TimeInterval) { RunLoop.current.run(until: Date().addingTimeInterval(s)) }

    private func dismissSystemAlerts(wait: TimeInterval) {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for label in ["Ask App Not to Track", "要求 App 不要追蹤", "Allow", "允許"] {
            let button = springboard.buttons[label]
            if button.waitForExistence(timeout: label == "Ask App Not to Track" ? wait : 0.5) {
                button.tap(); return
            }
        }
    }

    @discardableResult
    private func element(_ id: String) -> XCUIElement {
        let e = app.descendants(matching: .any)[id].firstMatch
        XCTAssertTrue(e.waitForExistence(timeout: 20), "missing \(id)")
        return e
    }

    private func tapIfExists(_ id: String) {
        let e = app.descendants(matching: .any)[id].firstMatch
        if e.exists { e.tap() }
    }

    private func tap(_ id: String) {
        let t = element(id)
        timed("tap \(id)") { t.tap() }
    }
}
