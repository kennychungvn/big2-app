import XCTest
import Foundation
@testable import ScoringEngine

/// Mutable clock used to exercise the minimum-interval check.
private final class TestClock: Clock, @unchecked Sendable {
    var now: Date

    init(_ now: Date) {
        self.now = now
    }

    func advance(by interval: TimeInterval) {
        now = now.addingTimeInterval(interval)
    }
}

final class InterstitialTests: XCTestCase {

    private let names = ["Kenny", "Ming", "Keung", "May"]
    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    private func session() throws -> Session {
        try Session(players: names)
    }

    private func fill(_ session: inout Session, rounds: Int) throws {
        for _ in 0..<rounds {
            try session.addRound(cardsLeft: [0, 1, 1, 1])
        }
    }

    func testNoAdBeforeAnyRoundsArePlayed() throws {
        let session = try session()
        XCTAssertFalse(session.shouldShowInterstitial(beforeStartingRound: 1, clock: TestClock(start)))
    }

    func testNoAdDuringTheFirstFourCompletedRounds() throws {
        var session = try session()
        let clock = TestClock(start)
        for completed in 1...4 {
            try fill(&session, rounds: 1)
            XCTAssertFalse(
                session.shouldShowInterstitial(beforeStartingRound: completed + 1, clock: clock),
                "Should not show an ad after \(completed) rounds"
            )
        }
    }

    func testShowsAdAfterFiveCompletedRoundsWhenStartingRoundSix() throws {
        var session = try session()
        try fill(&session, rounds: 5)
        XCTAssertTrue(session.shouldShowInterstitial(beforeStartingRound: 6, clock: TestClock(start)))
    }

    func testDoesNotShowWhenBeforeStartingRoundDoesNotMatchNextRound() throws {
        var session = try session()
        try fill(&session, rounds: 5)
        XCTAssertFalse(session.shouldShowInterstitial(beforeStartingRound: 5, clock: TestClock(start)))
        XCTAssertFalse(session.shouldShowInterstitial(beforeStartingRound: 7, clock: TestClock(start)))
    }

    func testMilestoneIsNotShownTwice() throws {
        var session = try session()
        let clock = TestClock(start)
        try fill(&session, rounds: 5)

        XCTAssertTrue(session.shouldShowInterstitial(beforeStartingRound: 6, clock: clock))
        session.recordInterstitialShown(clock: clock)
        XCTAssertFalse(session.shouldShowInterstitial(beforeStartingRound: 6, clock: clock))

        clock.advance(by: InterstitialPolicy.defaultMinimumInterval + 1)
        XCTAssertFalse(session.shouldShowInterstitial(beforeStartingRound: 6, clock: clock))
    }

    func testShowsAgainAtTheNextMultipleOfFive() throws {
        var session = try session()
        let clock = TestClock(start)

        try fill(&session, rounds: 5)
        XCTAssertTrue(session.shouldShowInterstitial(beforeStartingRound: 6, clock: clock))
        session.recordInterstitialShown(clock: clock)

        try fill(&session, rounds: 5) // now 10 completed
        clock.advance(by: InterstitialPolicy.defaultMinimumInterval)
        XCTAssertTrue(session.shouldShowInterstitial(beforeStartingRound: 11, clock: clock))
        session.recordInterstitialShown(clock: clock)

        try fill(&session, rounds: 5) // now 15
        clock.advance(by: InterstitialPolicy.defaultMinimumInterval)
        XCTAssertTrue(session.shouldShowInterstitial(beforeStartingRound: 16, clock: clock))
    }

    func testMinimumIntervalBlocksTheNextAd() throws {
        var session = try session()
        let clock = TestClock(start)

        try fill(&session, rounds: 5)
        session.recordInterstitialShown(clock: clock)

        try fill(&session, rounds: 5) // 10 completed, but only 60s later
        clock.advance(by: 60)
        XCTAssertFalse(session.shouldShowInterstitial(beforeStartingRound: 11, clock: clock))

        clock.advance(by: 119) // 179s total, still under 180
        XCTAssertFalse(session.shouldShowInterstitial(beforeStartingRound: 11, clock: clock))

        clock.advance(by: 1) // exactly 180s
        XCTAssertTrue(session.shouldShowInterstitial(beforeStartingRound: 11, clock: clock))
    }

    func testCustomMinimumIntervalIsHonored() throws {
        var session = try Session(
            players: names,
            interstitialMinimumInterval: 30
        )
        let clock = TestClock(start)
        try fill(&session, rounds: 5)
        session.recordInterstitialShown(clock: clock)
        try fill(&session, rounds: 5)

        clock.advance(by: 29)
        XCTAssertFalse(session.shouldShowInterstitial(beforeStartingRound: 11, clock: clock))
        clock.advance(by: 1)
        XCTAssertTrue(session.shouldShowInterstitial(beforeStartingRound: 11, clock: clock))
    }

    func testNewUserSeesFirstAdAfterFiveRounds() throws {
        var session = try session()
        try fill(&session, rounds: 5)
        XCTAssertTrue(session.shouldShowInterstitial(beforeStartingRound: 6, clock: TestClock(start)))
    }

    func testUndoDoesNotClearAShownMilestone() throws {
        var session = try session()
        let clock = TestClock(start)
        try fill(&session, rounds: 5)
        session.recordInterstitialShown(clock: clock)

        _ = try session.undoLastRound() // back to 4
        try session.addRound(cardsLeft: [0, 1, 1, 1]) // back to 5
        clock.advance(by: InterstitialPolicy.defaultMinimumInterval)
        XCTAssertFalse(
            session.shouldShowInterstitial(beforeStartingRound: 6, clock: clock),
            "A milestone already shown should not play again after undo/replay"
        )
    }

    func testDefaultMinimumIntervalIs180Seconds() {
        XCTAssertEqual(InterstitialPolicy.defaultMinimumInterval, 180)
        XCTAssertEqual(InterstitialPolicy.roundsPerAd, 5)
    }
}
