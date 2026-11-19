import XCTest
@testable import AppCore

final class ReviewPromptTests: XCTestCase {

    func testDoesNotRequestBeforeThirdCompletedGame() {
        XCTAssertFalse(ReviewPromptPolicy.shouldRequestReview(
            completedGameCount: 0, currentVersion: "1.0.2", lastPromptedVersion: nil
        ))
        XCTAssertFalse(ReviewPromptPolicy.shouldRequestReview(
            completedGameCount: 1, currentVersion: "1.0.2", lastPromptedVersion: nil
        ))
        XCTAssertFalse(ReviewPromptPolicy.shouldRequestReview(
            completedGameCount: 2, currentVersion: "1.0.2", lastPromptedVersion: nil
        ))
    }

    func testRequestsOnThirdCompletedGameWhenVersionNotYetPrompted() {
        XCTAssertTrue(ReviewPromptPolicy.shouldRequestReview(
            completedGameCount: 3, currentVersion: "1.0.2", lastPromptedVersion: nil
        ))
        XCTAssertTrue(ReviewPromptPolicy.shouldRequestReview(
            completedGameCount: 4, currentVersion: "1.0.2", lastPromptedVersion: nil
        ))
    }

    func testOncePerVersionDoesNotRequestAgainOnSameVersion() {
        XCTAssertFalse(ReviewPromptPolicy.shouldRequestReview(
            completedGameCount: 3, currentVersion: "1.0.2", lastPromptedVersion: "1.0.2"
        ))
        XCTAssertFalse(ReviewPromptPolicy.shouldRequestReview(
            completedGameCount: 10, currentVersion: "1.0.2", lastPromptedVersion: "1.0.2"
        ))
    }

    func testNewVersionCanRequestAgainAfterPreviousPrompt() {
        XCTAssertTrue(ReviewPromptPolicy.shouldRequestReview(
            completedGameCount: 3, currentVersion: "1.0.3", lastPromptedVersion: "1.0.2"
        ))
    }

    func testEmptyVersionNeverRequests() {
        XCTAssertFalse(ReviewPromptPolicy.shouldRequestReview(
            completedGameCount: 3, currentVersion: "", lastPromptedVersion: nil
        ))
        XCTAssertFalse(ReviewPromptPolicy.shouldRequestReview(
            completedGameCount: 3, currentVersion: "   ", lastPromptedVersion: nil
        ))
    }

    func testInitialCountSeedsFromExistingFinishedSessionsWhenNothingStored() {
        XCTAssertEqual(
            ReviewPromptPolicy.initialCompletedGameCount(storedCount: nil, existingFinishedSessionCount: 5),
            5
        )
        XCTAssertEqual(
            ReviewPromptPolicy.initialCompletedGameCount(storedCount: nil, existingFinishedSessionCount: 0),
            0
        )
        XCTAssertEqual(
            ReviewPromptPolicy.initialCompletedGameCount(storedCount: nil, existingFinishedSessionCount: -1),
            0
        )
    }

    func testInitialCountKeepsAStoredValueIncludingZero() {
        XCTAssertEqual(
            ReviewPromptPolicy.initialCompletedGameCount(storedCount: 0, existingFinishedSessionCount: 5),
            0
        )
        XCTAssertEqual(
            ReviewPromptPolicy.initialCompletedGameCount(storedCount: 2, existingFinishedSessionCount: 9),
            2
        )
    }

    func testStoreCountsGamesAndRemembersPromptedVersion() throws {
        let defaults = try makeSuite()
        defer { tearDownSuite(defaults) }
        let store = ReviewPromptStore(defaults: defaults)

        XCTAssertNil(store.storedCompletedGameCount)
        store.seedIfNeeded(existingFinishedSessionCount: 2)
        XCTAssertEqual(store.completedGameCount, 2)
        store.seedIfNeeded(existingFinishedSessionCount: 99)
        XCTAssertEqual(store.completedGameCount, 2)

        XCTAssertFalse(store.shouldRequestReview(currentVersion: "1.0.2"))
        store.recordFinishedGame()
        XCTAssertEqual(store.completedGameCount, 3)
        XCTAssertTrue(store.shouldRequestReview(currentVersion: "1.0.2"))

        store.recordPromptShown(for: "1.0.2")
        XCTAssertEqual(store.lastPromptedVersion, "1.0.2")
        XCTAssertFalse(store.shouldRequestReview(currentVersion: "1.0.2"))
        XCTAssertTrue(store.shouldRequestReview(currentVersion: "1.0.3"))
    }

    func testWriteReviewURLPointsAtTheAppStoreReviewAction() {
        XCTAssertEqual(
            ReviewPromptPolicy.writeReviewURL.absoluteString,
            "https://apps.apple.com/app/id6835281948?action=write-review"
        )
    }

    // MARK: - Defaults suite

    private func makeSuite() throws -> UserDefaults {
        let name = "review-prompt-tests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: name) else {
            throw XCTSkip("Could not create a UserDefaults suite")
        }
        defaults.removePersistentDomain(forName: name)
        defaults.set(name, forKey: "__suiteName")
        return defaults
    }

    private func tearDownSuite(_ defaults: UserDefaults) {
        let name = defaults.string(forKey: "__suiteName")
        if let name {
            defaults.removePersistentDomain(forName: name)
        }
    }
}
