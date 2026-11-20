import Foundation

/// Every AdMob identifier the app uses lives here (plus `GADApplicationIdentifier` in
/// App/Info.plist and App/Taiwan/Info.plist, which the SDK reads directly).
/// HK (鋤大D計分) and TW (大老二計分, `TAIWAN`) are separate AdMob apps with their own units.
///
/// Which units are used:
/// - Debug builds and TestFlight builds → Google's official TEST units (no invalid traffic).
/// - App Store (Release, not TestFlight) → the real units below.
///
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

    // MARK: Google's official test ids (https://developers.google.com/admob/ios/test-ads)

    /// Not used: test units work under the real app id in Info.plist. Kept for reference.
    static let testAppID = "ca-app-pub-3940256099942544~1458002511"
    static let testAdaptiveBannerUnitID = "ca-app-pub-3940256099942544/2435281174"
    static let testInterstitialUnitID = "ca-app-pub-3940256099942544/4411468910"

    // MARK: Resolved ids

    /// TEST units in Debug and TestFlight; real units only in App Store builds.
    static var isUsingTestAds: Bool {
        #if DEBUG
        return true
        #else
        return isTestFlightBuild
        #endif
    }

    /// TestFlight installs carry a sandbox receipt; App Store installs do not.
    static let isTestFlightBuild: Bool = {
        Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
    }()

    /// Same rule for both apps: test units in Debug / TestFlight, real units in App Store builds.
    static var bannerUnitID: String {
        isUsingTestAds ? testAdaptiveBannerUnitID : releaseBannerUnitID
    }

    static var interstitialUnitID: String {
        isUsingTestAds ? testInterstitialUnitID : releaseInterstitialUnitID
    }

    // MARK: UI tests

    /// `-uiTestAds`: UI tests skip the real SDK, UMP consent and the ATT prompt, and keep the
    /// placeholder banner (`banner`) and the closable stand-in interstitial
    /// (`interstitial.title` / `interstitial.close`).
    static var usesStubAds: Bool {
        ProcessInfo.processInfo.arguments.contains("-uiTestAds")
    }
}
