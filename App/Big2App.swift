import SwiftUI
import AppCore
import FirebaseCore
import FirebaseCrashlytics

@main
struct Big2App: App {
    @StateObject private var viewModel: AppViewModel

    init() {
        Self.configureCrashlytics()
        _viewModel = StateObject(wrappedValue: Self.makeViewModel())
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(viewModel)
                .environment(\.appTheme, viewModel.theme)
                .environment(\.locale, viewModel.region.locale)
                .task {
                    // UMP consent → ATT → MobileAds.start. Skipped once ads are removed and
                    // under -uiTestAds (UI tests keep the placeholder banner / stub interstitial).
                    guard !viewModel.model.data.adsRemoved else { return }
                    await AdsRuntime.shared.start()
                }
        }
    }

    /// Firebase is used for Crashlytics only (Analytics is not linked and is disabled in
    /// Info.plist / GoogleService-Info.plist). Crash reports are collected in Release builds
    /// (TestFlight / App Store); Debug builds do not send them.
    private static func configureCrashlytics() {
        guard Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil else { return }
        FirebaseApp.configure()
        #if DEBUG
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(false)
        #else
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
        #endif
    }

    @MainActor
    private static func makeViewModel() -> AppViewModel {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Big2", isDirectory: true)
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        let fileURL = support.appendingPathComponent("app-data.json")
        let ads: AdManaging = AdConfig.usesStubAds
            ? UITestInterstitialAdManager() as AdManaging
            : AdMobAdManager() as AdManaging
        if UITestSupport.isActive {
            try? FileManager.default.removeItem(at: fileURL)
            return AppViewModel(
                store: JSONFileStore(fileURL: fileURL),
                ads: ads,
                shop: StubStoreManager()
            )
        }
        let shop = StoreKitStoreManager()
        let viewModel = AppViewModel(
            store: JSONFileStore(fileURL: fileURL),
            ads: ads,
            shop: shop
        )
        shop.onEntitlementChange = { [weak viewModel] entitled in
            viewModel?.applyStoreEntitlement(entitled)
        }
        return viewModel
    }
}
