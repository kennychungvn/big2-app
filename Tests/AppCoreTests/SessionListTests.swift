import XCTest
import ScoringEngine
@testable import AppCore

final class SessionListTests: XCTestCase {

    private let names = ["權", "曦", "肥", "南"]
    private let start = Date(timeIntervalSince1970: 1_700_000_000)
    private let hk = TimeZone(identifier: "Asia/Hong_Kong")!

    private func stored(rounds: [[Int]], finished: Bool, players: [String]? = nil) throws -> StoredSession {
        var session = try Session(players: players ?? names, rule: .hongKongDefault, scoringMode: .winnerTakesAll)
        for cards in rounds { try session.addRound(cardsLeft: cards) }
        return StoredSession(session: session, createdAt: start, endedAt: finished ? start : nil)
    }

    // MARK: - 0-round sessions

    func testStartingNewSessionDeletesPreviousEmptySessions() throws {
        var model = AppModel()
        let clock = MutableClock(start)
        let empty = try model.startNewSession(players: names, chaoTable: .hongKongDefault, clock: clock)
        clock.advance(by: 60)
        let played = try model.startNewSession(players: names, chaoTable: .hongKongDefault, clock: clock)
        XCTAssertFalse(model.data.sessions.contains { $0.id == empty.id })
        try model.addRound(cardsLeft: [0, 1, 2, 3], clock: clock)
        clock.advance(by: 60)
        _ = try model.startNewSession(players: names, chaoTable: .hongKongDefault, clock: clock)
        XCTAssertTrue(model.data.sessions.contains { $0.id == played.id }, "sessions with rounds are kept")
        XCTAssertEqual(model.data.sessions.count, 2)
    }

    func testEmptySessionsAreNeverListedButCanBeContinued() throws {
        var model = AppModel()
        let clock = MutableClock(start)
        _ = try model.startNewSession(players: names, chaoTable: .hongKongDefault, clock: clock)
        try model.addRound(cardsLeft: [0, 1, 2, 3], clock: clock)
        try model.finishCurrentSession(clock: clock)
        clock.advance(by: 60)
        let empty = try model.startNewSession(players: names, chaoTable: .hongKongDefault, clock: clock)
        model.closeCurrentSession()
        XCTAssertEqual(model.latestUnfinished?.id, empty.id, "繼續上一場 still opens the 0-round session")
        XCTAssertFalse(model.allSessions.contains { $0.id == empty.id })
        XCTAssertFalse(model.homeRecentSessions.contains { $0.id == empty.id })
        XCTAssertEqual(model.allSessions.count, 1)
    }

    func testPurgeOnLaunchKeepsOnlyLatestUnfinishedEmptySession() throws {
        let old1 = try stored(rounds: [], finished: true)
        var old2 = try stored(rounds: [], finished: false)
        old2.updatedAt = start.addingTimeInterval(10)
        let played = try stored(rounds: [[0, 1, 2, 3]], finished: true)
        var latest = try stored(rounds: [], finished: false)
        latest.updatedAt = start.addingTimeInterval(100)
        var model = AppModel(data: AppData(sessions: [old1, old2, played, latest]))
        XCTAssertEqual(model.purgeEmptySessions(), 2)
        XCTAssertEqual(Set(model.data.sessions.map(\.id)), [played.id, latest.id])
        XCTAssertEqual(model.latestUnfinished?.id, latest.id)
        XCTAssertEqual(model.allSessions.map(\.id), [played.id])
        XCTAssertEqual(model.purgeEmptySessions(), 0)
    }

    func testPurgeRemovesAllEmptySessionsWhenLatestUnfinishedHasRounds() throws {
        let empty = try stored(rounds: [], finished: true)
        let unfinished = try stored(rounds: [[0, 1, 2, 3]], finished: false)
        var model = AppModel(data: AppData(sessions: [empty, unfinished]))
        XCTAssertEqual(model.purgeEmptySessions(), 1)
        XCTAssertEqual(model.data.sessions.map(\.id), [unfinished.id])
    }

    func testDeleteSession() throws {
        var model = AppModel()
        let clock = MutableClock(start)
        let stored = try model.startNewSession(players: names, chaoTable: .hongKongDefault, clock: clock)
        try model.addRound(cardsLeft: [0, 1, 2, 3], clock: clock)
        try model.deleteSession(stored.id)
        XCTAssertTrue(model.data.sessions.isEmpty)
        XCTAssertNil(model.currentSessionID)
        XCTAssertNil(model.latestUnfinished)
        XCTAssertThrowsError(try model.deleteSession(stored.id))
    }

    func testUnfinishedSessionsListFirst() throws {
        var finished = try stored(rounds: [[0, 1, 2, 3]], finished: true)
        finished.updatedAt = start.addingTimeInterval(500)
        let unfinished = try stored(rounds: [[0, 1, 2, 3]], finished: false)
        let model = AppModel(data: AppData(sessions: [finished, unfinished]))
        XCTAssertEqual(model.allSessions.map(\.id), [unfinished.id, finished.id])
        XCTAssertEqual(model.homeRecentSessions.map(\.id), [unfinished.id, finished.id])
    }

    // MARK: - Winner / tie

    func testSingleWinnerAndOthersSortedHighToLow() throws {
        // winner-takes-all, 1 張 ×1: 權 wins 1+2+3 = 6; 曦 −1, 肥 −2, 南 −3
        let summary = SessionListSummary(stored: try stored(rounds: [[0, 1, 2, 3]], finished: true))
        XCTAssertEqual(summary.winners.map(\.name), ["權"])
        XCTAssertEqual(summary.winningTotal, 6)
        XCTAssertEqual(summary.winnerLine(), "🏆 權 +6")
        XCTAssertEqual(summary.others.map(\.name), ["曦", "肥", "南"])
        XCTAssertEqual(summary.others.map(\.total), [-1, -2, -3])
    }

    func testTiedWinnersShareTheTrophy() throws {
        // Round 1: 權 wins (+6), Round 2: 曦 wins with the mirrored counts → 權 and 曦 tie.
        let summary = SessionListSummary(stored: try stored(rounds: [[0, 1, 2, 3], [1, 0, 2, 3]], finished: true))
        XCTAssertEqual(summary.winners.map(\.name), ["權", "曦"])
        XCTAssertEqual(summary.winnerNames, "權、曦")
        XCTAssertEqual(summary.winnerLine(), "🏆 權、曦 +5")
        XCTAssertEqual(summary.others.map(\.name), ["肥", "南"])
    }

    func testUnfinishedHasNoWinnerAndListsEveryone() throws {
        let summary = SessionListSummary(stored: try stored(rounds: [[0, 1, 2, 3]], finished: false))
        XCTAssertTrue(summary.winners.isEmpty)
        XCTAssertNil(summary.winnerLine())
        XCTAssertEqual(summary.others.count, 4)
        XCTAssertEqual(summary.others.map(\.total), summary.others.map(\.total).sorted(by: >))
    }

    // MARK: - Dates

    func testDayHeadersAndRowTitles() {
        let format = ScoreFormatting()
        // 1_700_000_000 = 2023-11-15 06:13 HKT
        let now = start.addingTimeInterval(3600)
        XCTAssertEqual(format.dayHeader(start, now: now, timeZone: hk), "今日")
        XCTAssertEqual(format.dayHeader(start, now: now.addingTimeInterval(86_400), timeZone: hk), "昨日")
        XCTAssertEqual(format.dayHeader(start, now: now.addingTimeInterval(3 * 86_400), timeZone: hk), "11/15")
        XCTAssertEqual(format.dayHeader(start, now: now.addingTimeInterval(400 * 86_400), timeZone: hk), "2023/11/15")
        XCTAssertEqual(ScoreFormatting(region: .taiwan).dayHeader(start, now: now, timeZone: hk), "今天")
        XCTAssertEqual(format.sessionRowTitle(date: start, rounds: 4, timeZone: hk), "06:13 · 4 局")
        XCTAssertEqual(format.sessionRowTitleWithDay(date: start, rounds: 4, now: now, timeZone: hk), "今日 06:13 · 4 局")
    }

    func testSectionsGroupConsecutiveSameDay() throws {
        let format = ScoreFormatting()
        let a = try stored(rounds: [[0, 1, 2, 3]], finished: false)
        let b = try stored(rounds: [[0, 1, 2, 3]], finished: true)
        var c = try stored(rounds: [[0, 1, 2, 3]], finished: true)
        c.createdAt = start.addingTimeInterval(-86_400)
        let sections = format.sections(for: [a, b, c], now: start, timeZone: hk)
        XCTAssertEqual(sections.map(\.title), ["今日", "昨日"])
        XCTAssertEqual(sections.map { $0.sessions.count }, [2, 1])
    }
}
