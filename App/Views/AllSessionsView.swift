import SwiftUI
import AppCore

/// 所有紀錄: every stored session, newest first. Tapping a row opens it on top of this list.
struct AllSessionsView: View {
    @EnvironmentObject private var vm: AppViewModel
    @Environment(\.appTheme) private var theme

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(vm.model.allSessions.enumerated()), id: \.element.id) { position, stored in
                    SessionRow(stored: stored) {
                        vm.openSession(stored, push: true)
                    }
                    .accessibilityIdentifier("all.row.\(position)")
                }
            }
            .padding(.vertical, 12)
        }
        .background(Color(theme.background).ignoresSafeArea())
        .navigationTitle(tr("所有紀錄"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(theme.background), for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}
