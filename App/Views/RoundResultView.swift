import SwiftUI
import AppCore
import ScoringEngine

struct RoundResultView: View {
    @EnvironmentObject private var vm: AppViewModel
    @Environment(\.appTheme) private var theme
    let sheet: ResultSheet

    var body: some View {
        let displays = RoundPresentation.displays(from: sheet.round)
        let receipts = RoundPresentation.winnerReceipts(from: sheet.round)
        let rankingOrder: [Int] = {
            let winner = sheet.round.winnerIndex
            return [winner] + (0..<sheet.players.count).filter { $0 != winner }
        }()

        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button("　　") {}
                        .foregroundColor(.clear)
                        .disabled(true)
                    Spacer()
                    Text(vm.format.resultTitle(sheet.roundNumber))
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(Color(theme.text))
                    Spacer()
                    Button("編輯") { vm.editFromResult() }
                        .font(.system(size: 15))
                        .foregroundColor(Color(theme.accentLink))
                }
                .padding(.horizontal, 18)
                .padding(.top, 16)
                .padding(.bottom, 12)

                ForEach(rankingOrder, id: \.self) { index in
                    resultRow(
                        index: index,
                        display: displays[index],
                        receipts: receipts
                    )
                }

                if vm.undoWindow != nil {
                    HStack {
                        Text("入錯？")
                        Spacer()
                        Button {
                            vm.performUndo()
                        } label: {
                            Text("↶ 撤回（5 秒）")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .buttonStyle(.plain)
                    }
                    .font(.system(size: 14))
                    .foregroundColor(Color(hexResult: 0xCFE0FF))
                    .padding(14)
                    .background(Color(theme.toastBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .padding(.horizontal, 14)
                    .padding(.top, 10)
                }

                Text("累計排名（\(vm.format.afterRoundTitle(sheet.roundNumber))）")
                    .font(.system(size: 14))
                    .foregroundColor(Color(theme.secondaryText))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 18)
                    .padding(.top, 14)

                let order = zip(sheet.players.indices, sheet.totalsAfter)
                    .sorted { lhs, rhs in
                        if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
                        return lhs.0 < rhs.0
                    }
                ForEach(Array(order.enumerated()), id: \.offset) { position, pair in
                    let (index, total) = pair
                    HStack {
                        Text("\(position + 1). \(sheet.players[index])")
                            .foregroundColor(Color(theme.text))
                        Spacer()
                        ScoreText(value: total, size: 17, format: vm.format)
                    }
                    .font(.system(size: 17))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(theme.historyRow))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 3)
                }

                Spacer(minLength: 8)
            }
            .background(Color(theme.background))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .padding(.top, 8)
            .padding(.horizontal, 0)
            .ignoresSafeArea(edges: .bottom)
        }
    }

    private func resultRow(index: Int, display: RoundScoreDisplay, receipts: [Int]) -> some View {
        let isWinner = display.cardsLeft == 0
        return HStack(spacing: 10) {
            PlayerColorDot(index: index, height: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(isWinner ? "\(sheet.players[index]) 👑" : sheet.players[index])
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(Color(theme.text))
                Text(vm.format.roundDetail(score: display, winnerReceivedFrom: isWinner ? receipts : []))
                    .font(.system(size: 13))
                    .foregroundColor(Color(theme.secondaryText))
            }
            Spacer()
            ScoreText(value: display.points, size: 28, format: vm.format)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(theme.card))
        .clipShape(RoundedRectangle(cornerRadius: theme.cardCornerRadius, style: .continuous))
        .padding(.horizontal, 14)
        .padding(.vertical, 5)
    }
}

private extension Color {
    init(hexResult: UInt32) {
        self.init(RGBColor(hex: hexResult))
    }
}
