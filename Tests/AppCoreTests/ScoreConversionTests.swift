import XCTest
import ScoringEngine
@testable import AppCore

final class ScoreConversionTests: XCTestCase {

    func testSanitizeKeepsDigitsOnlyAndCapsAtFour() {
        XCTAssertEqual(ScoreConversion.sanitize(""), "")
        XCTAssertEqual(ScoreConversion.sanitize("5"), "5")
        XCTAssertEqual(ScoreConversion.sanitize("50"), "50")
        XCTAssertEqual(ScoreConversion.sanitize("9999"), "9999")
        XCTAssertEqual(ScoreConversion.sanitize("12345"), "1234")
        XCTAssertEqual(ScoreConversion.sanitize("12.5"), "12")
        XCTAssertEqual(ScoreConversion.sanitize("12a3"), "123")
        XCTAssertEqual(ScoreConversion.sanitize("×5"), "5")
        XCTAssertEqual(ScoreConversion.sanitize("-5"), "5")
        XCTAssertEqual(ScoreConversion.sanitize(" 8 "), "8")
    }

    func testSanitizeStripsLeadingZerosButKeepsLoneZero() {
        XCTAssertEqual(ScoreConversion.sanitize("0"), "0")
        XCTAssertEqual(ScoreConversion.sanitize("00"), "0")
        XCTAssertEqual(ScoreConversion.sanitize("05"), "5")
        XCTAssertEqual(ScoreConversion.sanitize("0100"), "100")
        XCTAssertEqual(ScoreConversion.sanitize("1000"), "1000")
        XCTAssertEqual(ScoreConversion.sanitize("0000"), "0")
        XCTAssertEqual(ScoreConversion.sanitize("00005"), "0")
    }

    func testParse() {
        XCTAssertNil(ScoreConversion.parse(""))
        XCTAssertEqual(ScoreConversion.parse("0"), 0)
        XCTAssertEqual(ScoreConversion.parse("1"), 1)
        XCTAssertEqual(ScoreConversion.parse("5"), 5)
        XCTAssertEqual(ScoreConversion.parse("9999"), 9999)
    }

    func testAppliedMultiplierRequiresEnabledAndAtLeastTwo() {
        XCTAssertNil(ScoreConversion.appliedMultiplier(enabled: false, input: "5"))
        XCTAssertNil(ScoreConversion.appliedMultiplier(enabled: true, input: ""))
        XCTAssertNil(ScoreConversion.appliedMultiplier(enabled: true, input: "0"))
        XCTAssertNil(ScoreConversion.appliedMultiplier(enabled: true, input: "1"))
        XCTAssertEqual(ScoreConversion.appliedMultiplier(enabled: true, input: "2"), 2)
        XCTAssertEqual(ScoreConversion.appliedMultiplier(enabled: true, input: "5"), 5)
        XCTAssertEqual(ScoreConversion.appliedMultiplier(enabled: true, input: "05"), 5)
        XCTAssertEqual(ScoreConversion.appliedMultiplier(enabled: true, input: "9999"), 9999)

        XCTAssertNil(ScoreConversion.appliedMultiplier(enabled: false, multiplier: 5))
        XCTAssertNil(ScoreConversion.appliedMultiplier(enabled: true, multiplier: 0))
        XCTAssertNil(ScoreConversion.appliedMultiplier(enabled: true, multiplier: 1))
        XCTAssertNil(ScoreConversion.appliedMultiplier(enabled: true, multiplier: 10_000))
        XCTAssertEqual(ScoreConversion.appliedMultiplier(enabled: true, multiplier: 5), 5)
    }

    func testMultiply() {
        XCTAssertEqual(ScoreConversion.multiply(80, by: 5), 400)
        XCTAssertEqual(ScoreConversion.multiply(20, by: 5), 100)
        XCTAssertEqual(ScoreConversion.multiply(-30, by: 5), -150)
        XCTAssertEqual(ScoreConversion.multiply(-70, by: 5), -350)
        XCTAssertEqual(ScoreConversion.multiply(0, by: 5), 0)
        XCTAssertEqual(ScoreConversion.multiply(80, by: 1), 80)
        XCTAssertEqual(ScoreConversion.multiply(124, by: 5), 620)
        XCTAssertEqual(ScoreConversion.multiply(-196, by: 5), -980)
    }

    func testMultiplyClampsOverflow() {
        XCTAssertEqual(ScoreConversion.multiply(Int.max, by: 2), Int.max)
        XCTAssertEqual(ScoreConversion.multiply(Int.min, by: 2), Int.min)
        XCTAssertEqual(ScoreConversion.multiply(Int.max, by: 1), Int.max)
        XCTAssertEqual(ScoreConversion.multiply(Int.min, by: 1), Int.min)
        XCTAssertEqual(ScoreConversion.multiply(Int.max, by: 0), 0)
        XCTAssertEqual(ScoreConversion.multiply(Int.max / 2 + 1, by: 2), Int.max)
    }

    func testLineHasNoMoneyWording() {
        let line = ScoreConversion.line(multiplier: 5)
        XCTAssertEqual(line, "換算 ×5")
        XCTAssertFalse(line.contains("$"))
        XCTAssertFalse(line.contains("錢"))
        XCTAssertFalse(line.contains("蚊"))
        XCTAssertFalse(line.contains("HK$"))
    }

    func testShareSummaryUnchangedWhenConversionOff() throws {
        let stored = try sampleSession()
        let off = ShareSummary(stored: stored)
        let alsoOff = ShareSummary(stored: stored, conversionMultiplier: 1)
        XCTAssertEqual(off, alsoOff)
        XCTAssertNil(off.conversionLine)
        XCTAssertTrue(off.rows.allSatisfy { $0.originalPoints == nil })
        XCTAssertTrue(off.text.contains("+56"))
        XCTAssertFalse(off.text.contains("換算"))
        XCTAssertFalse(off.text.contains("（"))
        XCTAssertFalse(off.text.contains("$"))
        XCTAssertFalse(off.text.contains("錢"))
    }

    func testShareSummaryConvertedTextAndRows() throws {
        let stored = try sampleSession()
        let summary = ShareSummary(stored: stored, conversionMultiplier: 5)
        XCTAssertEqual(summary.conversionLine, "換算 ×5")
        XCTAssertTrue(summary.text.contains("換算 ×5"))
        // Kenny +56 ×5, 阿明 +36? wait compute from existing test:
        // displays: penalties 5 / 0 / 18 / 33, P = 56 → 56 − 4p
        // Kenny (index 1) is the winner with +56; ranking first.
        XCTAssertEqual(summary.rows.first?.name, "Kenny")
        XCTAssertEqual(summary.rows.first?.points, "+280")
        XCTAssertEqual(summary.rows.first?.originalPoints, "+56")
        XCTAssertTrue(summary.text.contains("1. 👑 Kenny  +280（+56）"))
        XCTAssertFalse(summary.text.contains("$"))
        XCTAssertFalse(summary.text.contains("錢"))
        XCTAssertFalse(summary.text.contains("蚊"))
        XCTAssertFalse(summary.text.contains("HK$"))

        // Values of 0 / below 2 do not convert.
        XCTAssertEqual(ShareSummary(stored: stored, conversionMultiplier: 0).conversionLine, nil)
    }

    private func sampleSession() throws -> StoredSession {
        var session = try Session(players: ["阿明", "Kenny", "阿強", "阿May"])
        try session.addRound(cardsLeft: [5, 0, 9, 11])
        return StoredSession(
            session: session,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            endedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }
}
