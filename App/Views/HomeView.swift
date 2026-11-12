import SwiftUI
import AppCore

struct HomeView: View {
    @EnvironmentObject private var vm: AppViewModel
    @Environment(\.appTheme) private var theme

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                VStack(spacing: 8) {
                    Text("🃏")
                        .font(.system(size: 64))
                    Text(tr("鋤大Dee 計分"))
                        .font(.system(size: 28, weight: .heavy))
                        .foregroundColor(Color(theme.text))
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
                .padding(.bottom, 30)

                PrimaryButton(title: tr("＋ 新開一場"), height: 96, fontSize: 26) {
                    vm.isPresentingNewSession = true
                }

                if let unfinished = vm.model.latestUnfinished {
                    Color.clear.frame(height: 14)
                    SecondaryButton(
                        title: tr("▶  繼續上一場"),
                        subtitle: "\(unfinished.playerSummary) · \(vm.format.afterRoundTitle(unfinished.session.roundsCompleted))"
                    ) {
                        vm.continueUnfinished()
                    }
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

                    ForEach(recents) { stored in
                        Button {
                            vm.openSession(stored)
                        } label: {
                            HStack {
                                Text(vm.format.sessionListSubtitle(date: stored.endedAt ?? stored.updatedAt, rounds: stored.session.roundsCompleted))
                                    .foregroundColor(Color(theme.text))
                                Spacer()
                                if stored.isFinished, let leader = stored.leaderSummary(format: vm.format) {
                                    let leadingPoints = stored.session.ranking.first?.total ?? 0
                                    Text(leader)
                                        .foregroundColor(leadingPoints >= 0 ? Color(theme.positive) : Color(theme.negative))
                                } else if !stored.isFinished {
                                    Text(tr("未完"))
                                        .foregroundColor(Color(theme.secondaryText))
                                }
                            }
                            .font(.system(size: 15))
                            .padding(.horizontal, 12)
                            .frame(height: 54)
                            .background(Color(theme.card))
                            .clipShape(RoundedRectangle(cornerRadius: theme.textFieldCornerRadius, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 5)
                    }
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
            }
        }
        .toolbarBackground(Color(theme.background), for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var recentList: [StoredSession] {
        let latestUnfinishedID = vm.model.latestUnfinished?.id
        return vm.model.recentSessions
            .filter { $0.id != latestUnfinishedID }
            .prefix(20)
            .map { $0 }
    }
}
