import Foundation

/// Every AdMob identifier the app uses lives here (plus `GADApplicationIdentifier` in
/// App/Info.plist, which the SDK reads directly and cannot come from code).
///
/// Right now Google's official TEST ids are active, so test ads show and nothing is billed.
///
/// TODO(Kenny, before release): AdMob publisher pub-3610638329659252
///   1. AdMob → Apps → Add app → iOS → "鋤大D計分" (link it to the App Store listing once live).
///   2. Create two ad units in that app: Banner (adaptive) and Interstitial.
///   3. Paste the unit ids into `releaseBannerUnitID` / `releaseInterstitialUnitID` below.
///   4. Paste the app id (ca-app-pub-3610638329659252~XXXXXXXXXX) into App/Info.plist
///      `GADApplicationIdentifier`, replacing Google's test app id.
///   5. Flip `useTestAds` to `false` (Debug builds keep test ads regardless).
enum AdConfig {
    // MARK: Switch

    /// `true` while the real ad units do not exist yet. Debug builds always use test ads so
    /// development never generates invalid traffic on the real units.
    static let useTestAds = true

    // MARK: Real ids (placeholders until Kenny creates them in AdMob)

    /// PLACEHOLDER: replace with the real Banner unit id, e.g. "ca-app-pub-3610638329659252/1234567890".
    static let releaseBannerUnitID = "ca-app-pub-3610638329659252/REPLACE_BANNER_UNIT_ID"
    /// PLACEHOLDER: replace with the real Interstitial unit id, e.g. "ca-app-pub-3610638329659252/0987654321".
    static let releaseInterstitialUnitID = "ca-app-pub-3610638329659252/REPLACE_INTERSTITIAL_UNIT_ID"

    // MARK: Google's official test ids (https://developers.google.com/admob/ios/test-ads)

    static let testAppID = "ca-app-pub-3940256099942544~1458002511"
    static let testAdaptiveBannerUnitID = "ca-app-pub-3940256099942544/2435281174"
    static let testInterstitialUnitID = "ca-app-pub-3940256099942544/4411468910"

    // MARK: Resolved ids

    static var isUsingTestAds: Bool {
        #if DEBUG
        return true
        #else
        return useTestAds
        #endif
    }

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
