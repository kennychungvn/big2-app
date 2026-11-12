import SwiftUI
import AppCore

@main
struct Big2App: App {
    @StateObject private var viewModel: AppViewModel

    init() {
        _viewModel = StateObject(wrappedValue: Self.makeViewModel())
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(viewModel)
                .environment(\.appTheme, viewModel.theme)
                .environment(\.locale, viewModel.region.locale)
        }
    }

    @MainActor
    private static func makeViewModel() -> AppViewModel {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Big2", isDirectory: true)
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        let fileURL = support.appendingPathComponent("app-data.json")
        if UITestSupport.isActive {
            try? FileManager.default.removeItem(at: fileURL)
            return AppViewModel(
                store: JSONFileStore(fileURL: fileURL),
                ads: UITestInterstitialAdManager(),
                shop: StubStoreManager()
            )
        }
        let store = JSONFileStore(fileURL: fileURL)
        return AppViewModel(
            store: store,
            ads: NoOpAdManager(),
            shop: StoreKitStoreManager()
        )
    }
}
