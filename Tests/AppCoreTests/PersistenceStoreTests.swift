import XCTest
import ScoringEngine
@testable import AppCore

final class PersistenceStoreTests: XCTestCase {

    func testInMemoryStoreRoundTrip() throws {
        let store = InMemoryStore()
        var data = AppData.empty
        data.adsRemoved = true
        data.knownPlayerNames = ["Kenny"]
        try store.save(data)
        XCTAssertEqual(try store.load().adsRemoved, true)
        XCTAssertEqual(try store.load().knownPlayerNames, ["Kenny"])
    }

    func testJSONFileStoreRoundTrip() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("big2-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let url = dir.appendingPathComponent("app-data.json")
        let store = JSONFileStore(fileURL: url)

        XCTAssertEqual(try store.load(), .empty)

        var model = AppModel()
        let clock = MutableClock(Date(timeIntervalSince1970: 1_700_000_000))
        _ = try model.startNewSession(
            players: ["阿明", "Kenny", "阿強", "阿May"],
            chaoTable: .hongKongDefault,
            clock: clock
        )
        try model.addRound(cardsLeft: [5, 0, 9, 11], clock: clock)
        model.setAdsRemoved(true)
        model.setHapticsEnabled(false)

        try store.save(model.data)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))

        let loaded = try store.load()
        XCTAssertEqual(loaded.adsRemoved, true)
        XCTAssertEqual(loaded.hapticsEnabled, false)
        XCTAssertEqual(loaded.sessions.count, 1)
        XCTAssertEqual(loaded.sessions[0].session.totals, [36, 56, -16, -76])
        XCTAssertEqual(loaded.lastSettings.playerNames, ["阿明", "Kenny", "阿強", "阿May"])
        XCTAssertEqual(loaded.knownPlayerNames.first, "阿明")

        // Overwrite still works (replace/move path).
        var second = loaded
        second.adsRemoved = false
        try store.save(second)
        XCTAssertEqual(try store.load().adsRemoved, false)
    }

    /// App killed mid-session: a fresh AppModel from the saved file resumes it via 繼續上一場
    /// (pairwise mode and rule kept) and can keep adding rounds.
    func testInProgressSessionSurvivesRelaunch() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("big2-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("app-data.json")
        let clock = MutableClock(Date(timeIntervalSince1970: 1_700_000_000))

        var before = AppModel()
        _ = try before.startNewSession(players: ["阿明", "阿強", "阿珍", "阿芬"], chaoTable: .hongKongDefault, clock: clock)
        try before.addRound(cardsLeft: [0, 11, 13, 3], clock: clock)
        try JSONFileStore(fileURL: url).save(before.data)

        // "Relaunch": nothing in memory, only the file.
        var after = AppModel(data: try JSONFileStore(fileURL: url).load())
        XCTAssertNil(after.currentSession)
        let unfinished = try XCTUnwrap(after.latestUnfinished)
        XCTAssertEqual(unfinished.session.roundsCompleted, 1)
        XCTAssertFalse(unfinished.isFinished)
        XCTAssertEqual(unfinished.session.scoringMode, .pairwise)
        XCTAssertEqual(unfinished.session.totals, [88, -44, -120, 76])

        let resumed = try after.continueUnfinished()
        XCTAssertEqual(resumed.id, unfinished.id)
        try after.addRound(cardsLeft: [4, 0, 2, 9], clock: clock)
        XCTAssertEqual(after.currentSession?.session.roundsCompleted, 2)
    }

    func testCorruptFileThrowsUnreadable() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("big2-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("app-data.json")
        try Data("not-json".utf8).write(to: url)
        let store = JSONFileStore(fileURL: url)
        XCTAssertThrowsError(try store.load()) { error in
            XCTAssertEqual(error as? PersistenceError, .unreadableFile)
        }
    }
}
