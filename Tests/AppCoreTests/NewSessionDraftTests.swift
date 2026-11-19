import XCTest
import ScoringEngine
@testable import AppCore

final class NewSessionDraftTests: XCTestCase {

    private let names = ["阿明", "Kenny", "阿強", "阿May"]

    func testPrefillUsesLastSettingsInSeatOrder() {
        let settings = LastSettings(playerNames: names)
        XCTAssertEqual(
            NewSessionDraft.prefilledPlayerNames(lastSettings: settings, sessions: []),
            names
        )
        let draft = NewSessionDraft(from: settings)
        XCTAssertEqual(draft.names, names)
        XCTAssertTrue(draft.canStart)
    }

    func testPrefillUsesEmptyDefaultsWhenThereIsNoPreviousGame() {
        XCTAssertEqual(
            NewSessionDraft.prefilledPlayerNames(lastSettings: LastSettings(), sessions: []),
            ["", "", "", ""]
        )
        let draft = NewSessionDraft()
        XCTAssertEqual(draft.names, NewSessionDraft.emptyNames)
        XCTAssertFalse(draft.canStart)
        XCTAssertFalse(draft.hasAnyName)
    }

    func testPrefillFallsBackToMostRecentSessionWhenLastSettingsAreEmpty() throws {
        let older = try Session(players: ["A", "B", "C", "D"])
        let newer = try Session(players: ["文仔", "呀權", "呀南", "小肥"])
        let sessions = [
            StoredSession(
                session: older,
                createdAt: Date(timeIntervalSince1970: 1),
                updatedAt: Date(timeIntervalSince1970: 1)
            ),
            StoredSession(
                session: newer,
                createdAt: Date(timeIntervalSince1970: 2),
                updatedAt: Date(timeIntervalSince1970: 5)
            ),
        ]
        XCTAssertEqual(
            NewSessionDraft.prefilledPlayerNames(lastSettings: LastSettings(), sessions: sessions),
            ["文仔", "呀權", "呀南", "小肥"]
        )
    }

    func testPrefillPrefersLastSettingsOverExistingSessions() throws {
        let session = try Session(players: ["A", "B", "C", "D"])
        let stored = StoredSession(
            session: session,
            createdAt: Date(timeIntervalSince1970: 1),
            updatedAt: Date(timeIntervalSince1970: 1)
        )
        XCTAssertEqual(
            NewSessionDraft.prefilledPlayerNames(
                lastSettings: LastSettings(playerNames: names),
                sessions: [stored]
            ),
            names
        )
    }

    func testClearAllNamesEmptiesEverySeat() {
        var draft = NewSessionDraft(from: LastSettings(playerNames: names))
        XCTAssertTrue(draft.hasAnyName)
        draft.clearAllNames()
        XCTAssertEqual(draft.names, ["", "", "", ""])
        XCTAssertFalse(draft.hasAnyName)
        XCTAssertFalse(draft.canStart)
    }
}
