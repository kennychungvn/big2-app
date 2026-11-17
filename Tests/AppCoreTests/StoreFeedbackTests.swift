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
