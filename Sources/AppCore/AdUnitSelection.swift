import Foundation

/// Official Google demo ad unit IDs for iOS.
/// Source: https://developers.google.com/admob/ios/test-ads (checked 2026-11-21).
/// These units are not associated with the publisher account, so requests cannot
/// generate invalid traffic. Production units live only in the app target (`AdConfig`).
public enum DemoAdUnits: Sendable {
    /// Anchored / inline adaptive banner. The app uses `currentOrientationAnchoredAdaptiveBanner`.
    public static let adaptiveBanner = "ca-app-pub-3940256099942544/2435281174"
    /// Fixed-size banner (320×50). The app does not use this format; listed to match the docs.
    public static let fixedBanner = "ca-app-pub-3940256099942544/2934735716"
    public static let interstitial = "ca-app-pub-3940256099942544/4411468910"
}

/// `AppTransaction.environment` (or the equivalent StoreKit value) when it has been read.
public enum AdStoreEnvironment: String, Equatable, Sendable {
    case production
    case sandbox
    case xcode
}

/// Everything the selector needs to tell an App Store install from every other build.
public struct AdInstallContext: Equatable, Sendable {
    public var isDebugBuild: Bool
    public var isSimulator: Bool
    /// `true` when `embedded.mobileprovision` is in the bundle (dev / Ad Hoc / Enterprise).
    /// App Store and TestFlight strip this file.
    public var hasEmbeddedMobileProvision: Bool
    /// Last path component of `Bundle.main.appStoreReceiptURL`, typically `sandboxReceipt`
    /// (TestFlight) or `receipt` (App Store). `nil` when the file is missing.
    public var receiptFileName: String?
    /// StoreKit 2 environment once read. `nil` if it has not been read or is unavailable.
    public var storeEnvironment: AdStoreEnvironment?

    public init(
        isDebugBuild: Bool,
        isSimulator: Bool,
        hasEmbeddedMobileProvision: Bool,
        receiptFileName: String?,
        storeEnvironment: AdStoreEnvironment?
    ) {
        self.isDebugBuild = isDebugBuild
        self.isSimulator = isSimulator
        self.hasEmbeddedMobileProvision = hasEmbeddedMobileProvision
        self.receiptFileName = receiptFileName
        self.storeEnvironment = storeEnvironment
    }
}

/// Which ad units this install may request.
public enum AdUnitSelection: Equatable, Sendable {
    /// Google's official demo units.
    case demo
    /// The app's own AdMob units. Only for a verified App Store production install.
    case production
    /// Not enough evidence to tell TestFlight from the App Store. Do not request ads.
    case undetermined

    /// Production units only when this install is positively identified as App Store.
    ///
    /// Debug, simulator, `embedded.mobileprovision`, a `sandboxReceipt`, and sandbox / Xcode
    /// StoreKit environments always select demo units. Those signals cannot appear on an
    /// App Store install, so an App Store build cannot fall through to demo ads by accident.
    ///
    /// When StoreKit reports `.production`, that wins even if the receipt file is missing
    /// (the receipt path is deprecated in iOS 18). A `receipt` file without a conflicting
    /// sandbox or dev signal also selects production. If neither StoreKit nor the receipt
    /// can decide, the result is `.undetermined` and the app must not request ads.
    public static func select(in context: AdInstallContext) -> AdUnitSelection {
        if context.isDebugBuild || context.isSimulator || context.hasEmbeddedMobileProvision {
            return .demo
        }
        switch context.storeEnvironment {
        case .production:
            return .production
        case .sandbox, .xcode:
            return .demo
        case nil:
            break
        }
        switch context.receiptFileName {
        case "sandboxReceipt":
            return .demo
        case "receipt":
            return .production
        default:
            return .undetermined
        }
    }
}
