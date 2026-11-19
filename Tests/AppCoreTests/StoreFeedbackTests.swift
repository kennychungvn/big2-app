import XCTest
@testable import AppCore

private struct FakeStoreKitError: Error, CustomStringConvertible {
    var description: String { "networkError" }
}

final class StoreFeedbackTests: XCTestCase {
    func testPurchaseFeedback() {
        XCTAssertEqual(StoreFeedback.purchase(.success(true)), .purchased)
        XCTAssertEqual(StoreFeedback.purchase(.success(false)), .purchaseFailed(.purchaseFailed))
        // Cancelling stays silent.
        XCTAssertNil(StoreFeedback.purchase(.failure(StoreError.cancelled)))
        XCTAssertEqual(StoreFeedback.purchase(.failure(StoreError.productNotFound)), .purchaseFailed(.productNotFound))
        XCTAssertEqual(StoreFeedback.purchase(.failure(StoreError.purchasePending)), .purchaseFailed(.purchasePending))
        XCTAssertEqual(StoreFeedback.purchase(.failure(StoreError.timedOut)), .purchaseFailed(.timedOut))
        XCTAssertEqual(
            StoreFeedback.purchase(.failure(StoreError.unverified("invalidSignature"))),
            .purchaseFailed(.unverified("invalidSignature"))
        )
    }

    func testForeignErrorsKeepTheirDescription() {
        guard case .purchaseFailed(.storeKit(let detail))? = StoreFeedback.purchase(.failure(FakeStoreKitError())) else {
            return XCTFail("expected .storeKit")
        }
        XCTAssertTrue(detail.contains("FakeStoreKitError"), detail)
        XCTAssertTrue(detail.contains("networkError"), detail)
        XCTAssertEqual(StoreError.storeKit("x").detail, "x")
        XCTAssertEqual(StoreError.unverified("y").detail, "y")
        XCTAssertNil(StoreError.timedOut.detail)
    }

    func testRestoreFeedbackAlwaysAnswers() {
        XCTAssertEqual(StoreFeedback.restore(.success(true)), .restored)
        XCTAssertEqual(StoreFeedback.restore(.success(false)), .nothingToRestore)
        XCTAssertEqual(StoreFeedback.restore(.failure(StoreError.cancelled)), .restoreFailed(.cancelled))
        XCTAssertEqual(StoreFeedback.restore(.failure(StoreError.timedOut)), .restoreFailed(.timedOut))
    }

    func testTimeoutReturnsFastResult() async throws {
        let value = try await StoreTimeout.run(seconds: 5) { 42 }
        XCTAssertEqual(value, 42)
    }

    func testTimeoutPassesErrorsThrough() async {
        do {
            _ = try await StoreTimeout.run(seconds: 5) { () async throws -> Int in throw StoreError.productNotFound }
            XCTFail("expected throw")
        } catch {
            XCTAssertEqual(error as? StoreError, .productNotFound)
        }
    }

    func testTimeoutStopsWaitingForAHungOperation() async {
        let start = Date()
        do {
            _ = try await StoreTimeout.run(seconds: 0.2) { () async throws -> Int in
                try await Task.sleep(nanoseconds: 5_000_000_000)
                return 1
            }
            XCTFail("expected timeout")
        } catch {
            XCTAssertEqual(error as? StoreError, .timedOut)
        }
        XCTAssertLessThan(Date().timeIntervalSince(start), 3)
    }

    @MainActor
    func testStubResetsBusyFlagAfterFailures() async {
        let store = StubStoreManager(purchaseResult: .failure(.storeKit("boom")), restoreResult: .failure(.timedOut))
        do { _ = try await store.purchaseRemoveAds(); XCTFail() } catch {}
        XCTAssertFalse(store.isPurchasing)
        do { _ = try await store.restorePurchases(); XCTFail() } catch {}
        XCTAssertFalse(store.isPurchasing)
        XCTAssertFalse(store.adsRemoved)
    }
}

final class StoreEventLogTests: XCTestCase {
    private func makeLog(limit: Int = 30) -> (StoreEventLog, UserDefaults) {
        let suite = "StoreEventLogTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return (StoreEventLog(defaults: defaults, key: "log", limit: limit), defaults)
    }

    func testKeepsOnlyTheLastEvents() {
        let (log, _) = makeLog(limit: 3)
        for i in 1...5 { log.append("e\(i)") }
        XCTAssertEqual(log.events.map(\.message), ["e3", "e4", "e5"])
    }

    func testPersistsAcrossInstances() {
        let (log, defaults) = makeLog()
        log.append("purchase start")
        let again = StoreEventLog(defaults: defaults, key: "log")
        XCTAssertEqual(again.events.map(\.message), ["purchase start"])
        again.clear()
        XCTAssertTrue(log.events.isEmpty)
    }

    func testDefaultLimitIsThirty() {
        let (log, _) = makeLog()
        for i in 1...45 { log.append("e\(i)") }
        XCTAssertEqual(log.events.count, 30)
        XCTAssertEqual(log.events.first?.message, "e16")
    }

    func testLongMessagesAreTrimmedAndExportHasOneLinePerEvent() {
        let (log, _) = makeLog()
        log.append(String(repeating: "x", count: 2000))
        log.append("restore result: cancelled")
        XCTAssertLessThanOrEqual(log.events[0].message.count, StoreEventLog.maxMessageLength + 1)
        let text = log.exportText(header: "header")
        let lines = text.split(separator: "\n")
        XCTAssertEqual(lines.count, 3)
        XCTAssertEqual(lines.first, "header")
        XCTAssertTrue(lines.last!.hasSuffix("restore result: cancelled"))
    }
}
