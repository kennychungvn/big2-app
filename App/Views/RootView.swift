import SwiftUI
import AppCore

struct RootView: View {
    @EnvironmentObject private var vm: AppViewModel
    @Environment(\.appTheme) private var theme

    var body: some View {
        NavigationStack(path: $vm.path) {
            HomeView()
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case .scoreboard(let id):
                        ScoreboardView(sessionID: id)
                    case .final(let id):
                        FinalView(sessionID: id)
                    }
                }
        }
        .tint(Color(theme.accentLink))
        .preferredColorScheme(.dark)
        .sheet(isPresented: $vm.isPresentingNewSession) {
            NewSessionView(draft: vm.model.newSessionDraft(region: vm.region))
                .environmentObject(vm)
                .environment(\.appTheme, theme)
                .environment(\.locale, vm.region.locale)
        }
        .sheet(isPresented: $vm.isPresentingSettings) {
            SettingsView()
                .environmentObject(vm)
                .environment(\.appTheme, theme)
                .environment(\.locale, vm.region.locale)
        }
        .fullScreenCover(item: $vm.roundEntry) { _ in
            if let binding = Binding($vm.roundEntry) {
                RoundEntryView(sheet: binding)
                    .environmentObject(vm)
                    .environment(\.appTheme, theme)
                .environment(\.locale, vm.region.locale)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if vm.roundEntry == nil {
                BannerAdContainer(adsRemoved: vm.model.data.adsRemoved)
            } else if !vm.model.data.adsRemoved {
                BannerAdContainer(adsRemoved: false)
            }
        }
        .alert(tr("提示"), isPresented: errorPresented) {
            Button(tr("知道")) { vm.errorMessage = nil }
        } message: {
            Text(vm.errorMessage ?? "")
        }
        .onAppear {
            vm.syncPurchasesFromStore()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSLocale.currentLocaleDidChangeNotification)) { _ in
            vm.refreshRegion()
        }
    }

    private var errorPresented: Binding<Bool> {
        Binding(
            get: { vm.errorMessage != nil },
            set: { if !$0 { vm.errorMessage = nil } }
        )
    }
}
