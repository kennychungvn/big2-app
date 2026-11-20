import XCTest
@testable import AppCore

final class ScoreRollTests: XCTestCase {
    func testTotalsBeforeSubtractsThisRound() {
        XCTAssertEqual(
            ScoreRoll.totalsBefore(after: [36, 56, -16, -76], points: [36, -12, 8, -32]),
            [0, 68, -24, -44]
        )
    }

    func testTotalsBeforeZipsToTheShorterArray() {
        XCTAssertEqual(ScoreRoll.totalsBefore(after: [10, 20], points: [1, 2, 3]), [9, 18])
        XCTAssertEqual(ScoreRoll.totalsBefore(after: [10, 20, 30], points: [1]), [9])
    }

    func testTotalsBeforeEmpty() {
        XCTAssertEqual(ScoreRoll.totalsBefore(after: [], points: []), [])
    }
}
