import SwiftUI
import AppCore

struct HomeView: View {
    @EnvironmentObject private var vm: AppViewModel
    @Environment(\.appTheme) private var theme
    @State private var pendingDelete: StoredSession?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.top, 8)
                    .padding(.bottom, 18)

                if let unfinished = vm.model.latestUnfinished {
                    inProgressCard(unfinished)
                        .padding(.bottom, 16)
                }

                PrimaryButton(title: tr("＋ 新開一場"), height: 60, fontSize: 19) {
                    vm.isPresentingNewSession = true
                }
                .accessibilityIdentifier("home.newSession")

                let recents = recentList
                if !recents.isEmpty {
                    HStack {
                        Text(tr("最近場次"))
                            .font(ThemeFont.sectionLabel(theme))
                            .foregroundColor(Color(theme.secondaryText))
                        Spacer()
                        if !vm.model.allSessions.isEmpty {
                            NavigationLink(value: AppRoute.allSessions) {
                                HStack(spacing: 3) {
                                    Text(tr("所有紀錄"))
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 11, weight: .semibold))
                                }
                                .font(.system(size: 13))
                                .foregroundColor(Color(theme.secondaryText))
                                .frame(minHeight: 32)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("home.allSessions")
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 22)
                    .padding(.bottom, 4)

                    VStack(spacing: 0) {
                        ForEach(Array(recents.enumerated()), id: \.element.id) { position, stored in
                            if position > 0 {
                                Rectangle()
                                    .fill(Color(theme.line))
                                    .frame(height: 1)
                                    .padding(.leading, 14)
                            }
                            SessionRow(stored: stored, showsDay: true, grouped: true) {
                                vm.openSession(stored)
                            }
                            .accessibilityIdentifier("home.recent.\(position)")
                            // A ScrollView has no swipe actions; long-press offers 刪除 instead.
                            .contextMenu {
                                Button(role: .destructive) {
                                    pendingDelete = stored
                                } label: {
                                    Label(tr("刪除"), systemImage: "trash")
                                }
                            }
                        }
                    }
                    .themedCard(theme)
                    .padding(.horizontal, 16)
                } else if !vm.model.allSessions.isEmpty {
                    NavigationLink(value: AppRoute.allSessions) {
                        HStack {
                            Text(tr("所有紀錄"))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color(theme.accentLink))
                        .padding(.horizontal, 14)
                        .frame(height: 48)
                        .frame(maxWidth: .infinity)
                        .themedCard(theme)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("home.allSessions")
                    .padding(.horizontal, 16)
                    .padding(.top, 22)
                } else if vm.model.latestUnfinished == nil {
                    Text(tr("未有對局紀錄，撳「新開一場」開始。"))
                        .font(.system(size: 13))
                        .foregroundColor(Color(theme.tertiaryText))
                        .frame(maxWidth: .infinity)
                        .padding(.top, 28)
                }
            }
            .padding(.bottom, 12)
        }
        .background(Color(theme.background).ignoresSafeArea())
        .deleteSessionAlert(pending: $pendingDelete) { vm.deleteSession($0.id) }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image((vm.iconFollowsSkin ? vm.skin : AppIconSwitcher.current).iconPreviewName)
                .resizable()
                .scaledToFit()
                .frame(width: 36, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .accessibilityHidden(true)
            Text(AppFlavor.current.isTaiwanApp ? AppFlavor.current.displayName : tr("鋤大D計分"))
                .accessibilityIdentifier("home.title")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(Color(theme.text))
            Spacer()
            Button {
                vm.isPresentingSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(Color(theme.secondaryText))
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color(theme.surface2)))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(tr("設定"))
            .accessibilityIdentifier("home.settings")
        }
        .padding(.horizontal, 16)
    }

    /// 進行中: running totals of the open game (existing session data) + 繼續.
    private func inProgressCard(_ unfinished: StoredSession) -> some View {
        let session = unfinished.session
        let totals = session.totals
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(tr("進行中"))
                    .font(ThemeFont.sectionLabel(theme))
                    .foregroundColor(Color(theme.secondaryText))
                Spacer()
                Text(vm.format.homeProgress(session.roundsCompleted))
                    .font(.system(size: 13))
                    .foregroundColor(Color(theme.secondaryText))
            }
            .padding(.horizontal, 4)

            VStack(spacing: 12) {
                HStack(alignment: .top, spacing: 4) {
                    ForEach(Array(session.players.enumerated()), id: \.offset) { index, name in
                        VStack(spacing: 4) {
                            HStack(spacing: 5) {
                                PlayerColorDot(index: index, height: 16)
                                Text(name)
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(theme.secondaryText))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }
                            RollingScoreText(value: totals.indices.contains(index) ? totals[index] : 0, size: 24, format: vm.format, column: index)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                Button {
                    vm.continueUnfinished()
                } label: {
                    Text(tr("繼續呢場 →"))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(theme.text))
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color(theme.surface2))
                        .clipShape(RoundedRectangle(cornerRadius: theme.buttonCornerRadius - 4, style: .continuous))
                }
                .buttonStyle(PressStyle(amount: 0.97))
                .accessibilityIdentifier("home.continue")
                .accessibilityLabel(tr("繼續呢場"))
                .accessibilityValue("\(unfinished.playerSummary) · \(vm.format.homeProgress(session.roundsCompleted))")
            }
            .padding(14)
            .themedCard(theme)
        }
        .padding(.horizontal, 16)
    }

    private var recentList: [StoredSession] {
        vm.model.homeRecentSessions
    }
}
