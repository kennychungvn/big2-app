import SwiftUI
import AppCore
import ScoringEngine

struct ScoreboardView: View {
    @EnvironmentObject private var vm: AppViewModel
    @Environment(\.appTheme) private var theme
    let sessionID: UUID

    @State private var isConfirmingFinish = false

    var body: some View {
        Group {
            if let stored = stored {
                content(stored)
            } else {
                Text(tr("搵唔到呢場。"))
                    .foregroundColor(Color(theme.secondaryText))
            }
        }
        .background(Color(theme.background).ignoresSafeArea())
        .keepAwake(true)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(tr("‹ 首頁")) { vm.goHome() }
                    .accessibilityIdentifier("nav.home")
                    .foregroundColor(Color(theme.accentLink))
            }
            ToolbarItem(placement: .principal) {
                Text(vm.format.homeProgress(stored?.session.roundsCompleted ?? 0))
                    .accessibilityIdentifier("scoreboard.title")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color(theme.text))
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(tr("完場|nav")) { isConfirmingFinish = true }
                    .accessibilityIdentifier("scoreboard.finish")
                    .foregroundColor(Color(theme.accentLink))
            }
        }
        .toolbarBackground(Color(theme.background), for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .alert(tr("確定完場？"), isPresented: $isConfirmingFinish) {
            Button(tr("取消"), role: .cancel) {}
            Button(tr("完場|nav"), role: .destructive) {
                Task {
                    // Let the alert finish dismissing before the interstitial / navigation.
                    try? await Task.sleep(nanoseconds: 400_000_000)
                    await vm.finishCurrentSession()
                }
            }
        } message: {
            Text(tr("完場後會計最終排名，之後唔可以再加局。"))
        }
    }

    private var stored: StoredSession? {
        vm.model.data.sessions.first(where: { $0.id == sessionID }) ?? vm.model.currentSession
    }

    @ViewBuilder
    private func content(_ stored: StoredSession) -> some View {
        let session = stored.session
        let ranking = session.ranking
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                        ForEach(ranking, id: \.index) { player in
                            playerCard(player)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 4)

                    Text(tr("每局紀錄 · 㩒一行改分"))
                        .font(.system(size: 13))
                        .foregroundColor(Color(theme.secondaryText))
                        .padding(.horizontal, 18)
                        .padding(.top, 14)
                        .padding(.bottom, 6)

                    if session.roundsCompleted == 0 {
                        Text(tr("未有紀錄，打完第一局㩒下面「入今局」"))
                            .accessibilityIdentifier("scoreboard.empty")
                            .font(.system(size: 14))
                            .foregroundColor(Color(theme.secondaryText))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 28)
                    } else {
                        historyHeader(session.players)
                    }
                    ForEach(vm.model.historyRows()) { row in
                        Button {
                            vm.reviewRound(at: row.index)
                        } label: {
                            historyRow(row, names: session.players)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("scoreboard.history.\(row.index)")
                    }
                }
                .padding(.bottom, 8)
            }

            if let window = vm.undoWindow, vm.resultSheet == nil {
                undoToast(window)
            }

            PrimaryButton(title: tr("＋ 入今局")) {
                Task { await vm.startEnteringRound() }
            }
            .accessibilityIdentifier("scoreboard.addRound")
            .padding(.top, 10)
            .padding(.bottom, 0)

            AdSafeGap()
        }
    }

    private func playerCard(_ player: RankedPlayer) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                if player.rank == 1 && (stored?.session.roundsCompleted ?? 0) > 0 {
                    Text("👑")
                }
                Text(player.name)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color(theme.text))
                    .lineLimit(1)
            }
            ScoreText(value: player.total, size: 34, format: vm.format)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 112)
        .background(Color(theme.card))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Color(theme.playerColor(at: player.index)))
                .frame(width: 6, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                .offset(y: -16)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(player.name) \(vm.format.points(player.total))")
        .accessibilityIdentifier("scoreboard.player.\(player.index)")
    }

    private func historyHeader(_ names: [String]) -> some View {
        HStack(spacing: 0) {
            Text(tr("局"))
                .frame(width: 52, alignment: .leading)
            ForEach(Array(names.enumerated()), id: \.offset) { _, name in
                Text(name)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .lineLimit(1)
            }
        }
        .font(.system(size: 12))
        .foregroundColor(Color(theme.secondaryText))
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .padding(.horizontal, 14)
    }

    private func historyRow(_ row: RoundHistoryRow, names: [String]) -> some View {
        HStack(spacing: 0) {
            Text("\(row.roundNumber)")
                .foregroundColor(Color(theme.secondaryText))
                .frame(width: 52, alignment: .leading)
            ForEach(Array(row.points.enumerated()), id: \.offset) { _, points in
                Text(vm.format.points(points))
                    .foregroundColor(points > 0 ? Color(theme.positive) : (points < 0 ? Color(theme.negative) : Color(theme.text)))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .font(.system(size: 14, weight: .medium))
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(theme.historyRow))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .padding(.horizontal, 14)
        .padding(.vertical, 3)
    }

    private func undoToast(_ window: UndoWindow) -> some View {
        HStack {
            Text(tr("入錯咗？"))
                .accessibilityIdentifier("scoreboard.undoToast")
            Spacer()
            Button {
                vm.performUndo()
            } label: {
                Text(tr("↶ 撤回"))
                    .font(.system(size: 14, weight: .bold))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("scoreboard.undo")
        }
        .font(.system(size: 14))
        .foregroundColor(Color(hexText: 0xCFE0FF))
        .padding(14)
        .background(Color(theme.toastBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 14)
        .padding(.top, 8)
    }
}

private extension Color {
    init(hexText: UInt32) {
        self.init(RGBColor(hex: hexText))
    }
}
