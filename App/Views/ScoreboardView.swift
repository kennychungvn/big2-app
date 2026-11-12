import SwiftUI
import AppCore
import ScoringEngine

struct ScoreboardView: View {
    @EnvironmentObject private var vm: AppViewModel
    @Environment(\.appTheme) private var theme
    let sessionID: UUID

    var body: some View {
        Group {
            if let stored = stored {
                content(stored)
            } else {
                Text("搵唔到呢場。")
                    .foregroundColor(Color(theme.secondaryText))
            }
        }
        .background(Color(theme.background).ignoresSafeArea())
        .keepAwake(true)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("‹ 首頁") { vm.goHome() }
                    .foregroundColor(Color(theme.accentLink))
            }
            ToolbarItem(placement: .principal) {
                Text(vm.format.afterRoundTitle(stored?.session.roundsCompleted ?? 0))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color(theme.text))
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("完場") { vm.finishCurrentSession() }
                    .foregroundColor(Color(theme.accentLink))
            }
        }
        .toolbarBackground(Color(theme.background), for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
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

                    Text("每局紀錄（㩒一行可編輯）")
                        .font(.system(size: 13))
                        .foregroundColor(Color(theme.secondaryText))
                        .padding(.horizontal, 18)
                        .padding(.top, 14)
                        .padding(.bottom, 6)

                    historyHeader(session.players)
                    ForEach(vm.model.historyRows()) { row in
                        Button {
                            vm.editRound(at: row.index)
                        } label: {
                            historyRow(row, names: session.players)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, 8)
            }

            if let window = vm.undoWindow, vm.resultSheet == nil {
                undoToast(window)
            }

            PrimaryButton(title: "＋ 入今局") {
                Task { await vm.startEnteringRound() }
            }
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
            MoneyText(value: player.money, format: vm.format)
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
    }

    private func historyHeader(_ names: [String]) -> some View {
        HStack(spacing: 0) {
            Text("局")
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
            Text("入錯？")
            Spacer()
            Button {
                vm.performUndo()
            } label: {
                Text("↶ 撤回")
                    .font(.system(size: 14, weight: .bold))
            }
            .buttonStyle(.plain)
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
