import Foundation
import StoreKit
import AppCore

/// Every AdMob identifier the app uses lives here (plus `GADApplicationIdentifier` in
/// App/Info.plist and App/Taiwan/Info.plist, which the SDK reads directly).
/// HK (鋤大D計分) and TW (大老二計分, `TAIWAN`) are separate AdMob apps with their own units.
///
/// Production units are used only on a verified App Store install. Debug, simulator,
/// dev / Ad Hoc, and TestFlight installs use Google's official demo units
/// (https://developers.google.com/admob/ios/test-ads). The Info.plist app id stays
/// the real one; the SDK requires it, and demo units work under it.
enum AdConfig {
    // MARK: Real ids (AdMob publisher pub-3610638329659252)

    #if TAIWAN
    // 大老二計分 (com.kenny.dalaoer)
    static let releaseAppID = "ca-app-pub-3610638329659252~6972663415"
    static let releaseBannerUnitID = "ca-app-pub-3610638329659252/5512689191"
    static let releaseInterstitialUnitID = "ca-app-pub-3610638329659252/4199607523"
    #else
    // 鋤大D計分 (com.kenny.daidee)
    static let releaseAppID = "ca-app-pub-3610638329659252~9118674558"
    static let releaseBannerUnitID = "ca-app-pub-3610638329659252/6728314939"
    static let releaseInterstitialUnitID = "ca-app-pub-3610638329659252/4651835990"
    #endif

    // MARK: Google's official demo ids

    /// The app serves anchored adaptive banners, so this is `DemoAdUnits.adaptiveBanner`
    /// (`…/2435281174`), not the fixed-size banner id (`…/2934735716`).
    static let testAdaptiveBannerUnitID = DemoAdUnits.adaptiveBanner
    static let testInterstitialUnitID = DemoAdUnits.interstitial

    // MARK: Resolved ids

    private static var resolvedStoreEnvironment: AdStoreEnvironment?
    private static var didResolveStoreEnvironment = false

    static var installContext: AdInstallContext {
        AdInstallContext(
            isDebugBuild: isDebugBuild,
            isSimulator: isSimulator,
            hasEmbeddedMobileProvision: hasEmbeddedMobileProvision,
            receiptFileName: receiptFileName,
            storeEnvironment: resolvedStoreEnvironment
        )
    }

    static var selection: AdUnitSelection {
        AdUnitSelection.select(in: installContext)
    }

    /// Demo units in Debug, simulator, dev / Ad Hoc, and TestFlight; real units only
    /// in a verified App Store build.
    static var isUsingTestAds: Bool { selection == .demo }

    /// True when the receipt file is the TestFlight / sandbox receipt. Prefer `selection`.
    static var isTestFlightBuild: Bool { receiptFileName == "sandboxReceipt" }

    static var bannerUnitID: String {
        isUsingTestAds ? DemoAdUnits.adaptiveBanner : releaseBannerUnitID
    }

    static var interstitialUnitID: String {
        isUsingTestAds ? DemoAdUnits.interstitial : releaseInterstitialUnitID
    }

    // MARK: UI tests

    /// `-uiTestAds`: UI tests skip the real SDK, UMP consent and the ATT prompt, and keep the
    /// placeholder banner (`banner`) and the closable stand-in interstitial
    /// (`interstitial.title` / `interstitial.close`).
    static var usesStubAds: Bool {
        ProcessInfo.processInfo.arguments.contains("-uiTestAds")
    }

    // MARK: Install signals

    static var isDebugBuild: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }

    static var isSimulator: Bool {
        #if targetEnvironment(simulator)
        true
        #else
        false
        #endif
    }

    static var hasEmbeddedMobileProvision: Bool {
        Bundle.main.path(forResource: "embedded", ofType: "mobileprovision") != nil
    }

    static var receiptFileName: String? {
        Bundle.main.appStoreReceiptURL?.lastPathComponent
    }

    /// Reads `AppTransaction.environment` when the sync signals are not already decisive.
    /// Safe to call more than once; the StoreKit result is cached. Times out after 5 s so
    /// a hung StoreKit call cannot block start-up.
    @MainActor
    static func resolveInstallContext() async {
        if AdUnitSelection.select(in: installContext) != .undetermined { return }
        guard !didResolveStoreEnvironment else { return }
        didResolveStoreEnvironment = true
        resolvedStoreEnvironment = await readStoreEnvironment()
    }

    private static func readStoreEnvironment() async -> AdStoreEnvironment? {
        guard #available(iOS 16.0, *) else { return nil }
        return await withTaskGroup(of: AdStoreEnvironment?.self) { group in
            group.addTask {
                do {
                    let result = try await AppTransaction.shared
                    let transaction: AppTransaction
                    switch result {
                    case .verified(let value):
                        transaction = value
                    case .unverified(let value, _):
                        transaction = value
                    }
                    switch transaction.environment {
                    case .production: return .production
                    case .sandbox: return .sandbox
                    case .xcode: return .xcode
                    default: return nil
                    }
                } catch {
                    NSLog("[Ads] AppTransaction unavailable: \(error.localizedDescription)")
                    return nil
                }
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first ?? nil
        }
    }
}
