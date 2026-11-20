import XCTest
@testable import AppCore

final class AdUnitSelectionTests: XCTestCase {
    func testOfficialDemoUnitIDsMatchGoogleDocs() {
        // https://developers.google.com/admob/ios/test-ads (checked 2026-11-21)
        XCTAssertEqual(DemoAdUnits.adaptiveBanner, "ca-app-pub-3940256099942544/2435281174")
        XCTAssertEqual(DemoAdUnits.fixedBanner, "ca-app-pub-3940256099942544/2934735716")
        XCTAssertEqual(DemoAdUnits.interstitial, "ca-app-pub-3940256099942544/4411468910")
    }

    func testDebugBuildAlwaysUsesDemoUnits() {
        XCTAssertEqual(select(debug: true, receipt: "receipt", store: .production), .demo)
    }

    func testReleaseSimulatorUsesDemoUnits() {
        // CI hang tests: Release configuration on the simulator, no TestFlight receipt.
        XCTAssertEqual(select(simulator: true, receipt: nil, store: nil), .demo)
        XCTAssertEqual(select(simulator: true, receipt: "receipt", store: .production), .demo)
    }

    func testEmbeddedMobileProvisionUsesDemoUnits() {
        XCTAssertEqual(select(provision: true, receipt: "receipt", store: .production), .demo)
    }

    func testSandboxReceiptWithoutStoreEnvironmentUsesDemoUnits() {
        XCTAssertEqual(select(receipt: "sandboxReceipt"), .demo)
    }

    func testSandboxStoreEnvironmentWithoutReceiptUsesDemoUnits() {
        XCTAssertEqual(select(store: .sandbox), .demo)
    }

    func testXcodeStoreEnvironmentUsesDemoUnits() {
        XCTAssertEqual(select(store: .xcode), .demo)
    }

    func testProductionStoreEnvironmentWithoutReceiptUsesProductionUnits() {
        XCTAssertEqual(select(store: .production), .production)
    }

    func testAppStoreReceiptWithoutStoreEnvironmentUsesProductionUnits() {
        XCTAssertEqual(select(receipt: "receipt"), .production)
    }

    func testProductionStoreEnvironmentWinsOverSandboxReceipt() {
        XCTAssertEqual(select(receipt: "sandboxReceipt", store: .production), .production)
    }

    func testSandboxStoreEnvironmentWinsOverAppStoreReceipt() {
        XCTAssertEqual(select(receipt: "receipt", store: .sandbox), .demo)
    }

    func testReleaseDeviceWithNoSignalsIsUndetermined() {
        XCTAssertEqual(select(), .undetermined)
        XCTAssertEqual(select(receipt: ""), .undetermined)
        XCTAssertEqual(select(receipt: "other"), .undetermined)
    }

    func testAppStoreReleaseDeviceIsProduction() {
        XCTAssertEqual(
            select(receipt: "receipt", store: .production),
            .production
        )
    }

    func testTestFlightReleaseDeviceIsDemo() {
        XCTAssertEqual(
            select(receipt: "sandboxReceipt", store: .sandbox),
            .demo
        )
    }

    private func select(
        debug: Bool = false,
        simulator: Bool = false,
        provision: Bool = false,
        receipt: String? = nil,
        store: AdStoreEnvironment? = nil
    ) -> AdUnitSelection {
        AdUnitSelection.select(
            in: AdInstallContext(
                isDebugBuild: debug,
                isSimulator: simulator,
                hasEmbeddedMobileProvision: provision,
                receiptFileName: receipt,
                storeEnvironment: store
            )
        )
    }
}
