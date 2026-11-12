import SwiftUI
import AppCore

struct HomeView: View {
    @EnvironmentObject private var vm: AppViewModel
    @Environment(\.appTheme) private var theme

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                VStack(spacing: 8) {
                    Image("HomeLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 88, height: 88)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .accessibilityHidden(true)
                    Text(tr("鋤大D計分"))
                        .accessibilityIdentifier("home.title")
                        .font(.system(size: 28, weight: .heavy))
                        .foregroundColor(Color(theme.text))
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
                .padding(.bottom, 30)

                PrimaryButton(title: tr("＋ 新開一場"), height: 96, fontSize: 26) {
                    vm.isPresentingNewSession = true
                }
                .accessibilityIdentifier("home.newSession")

                if let unfinished = vm.model.latestUnfinished {
                    Color.clear.frame(height: 14)
                    SecondaryButton(
                        title: tr("▶  繼續上一場"),
                        subtitle: "\(unfinished.playerSummary) · \(vm.format.homeProgress(unfinished.session.roundsCompleted))"
                    ) {
                        vm.continueUnfinished()
                    }
                    .accessibilityIdentifier("home.continue")
                }

                let recents = recentList
                if !recents.isEmpty {
                    HStack {
                        Text(tr("最近場次"))
                            .font(.system(size: 13))
                            .foregroundColor(Color(theme.secondaryText))
                        Spacer()
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 26)
                    .padding(.bottom, 6)

                    ForEach(Array(recents.enumerated()), id: \.element.id) { position, stored in
                        SessionRow(stored: stored) {
                            vm.openSession(stored)
                        }
                        .accessibilityIdentifier("home.recent.\(position)")
                    }
                }

                if !vm.model.allSessions.isEmpty {
                    // Button + path append rather than NavigationLink(value:): the link was
                    // ignored after the path had been reset programmatically (完場 → 首頁).
                    Button {
                        vm.path.append(.allSessions)
                    } label: {
                        HStack {
                            Text(tr("所有紀錄"))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color(theme.accentLink))
                        .padding(.horizontal, 12)
                        .frame(height: 48)
                        .frame(maxWidth: .infinity)
                        .overlay(
                            RoundedRectangle(cornerRadius: theme.textFieldCornerRadius, style: .continuous)
                                .stroke(Color(theme.card), lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("home.allSessions")
                    .padding(.horizontal, 14)
                    .padding(.top, recents.isEmpty ? 26 : 8)
                }
            }
            .padding(.bottom, 12)
        }
        .background(Color(theme.background).ignoresSafeArea())
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    vm.isPresentingSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .foregroundColor(Color(theme.accentLink))
                }
                .accessibilityLabel(tr("設定"))
                .accessibilityIdentifier("home.settings")
            }
        }
        .toolbarBackground(Color(theme.background), for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var recentList: [StoredSession] {
        vm.model.homeRecentSessions
    }
}
