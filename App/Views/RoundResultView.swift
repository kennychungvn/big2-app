import SwiftUI
import AppCore
import ScoringEngine

struct RoundResultView: View {
    @EnvironmentObject private var vm: AppViewModel
    @Environment(\.appTheme) private var theme
    let sheet: ResultSheet

    var body: some View {
        let displays = RoundPresentation.displays(from: sheet.round)
        let rankingOrder: [Int] = {
            let winner = sheet.round.winnerIndex
            return [winner] + (0..<sheet.players.count).filter { $0 != winner }
        }()

        let breakdown = sheet.scoringMode == .pairwise ? RoundPresentation.pairwiseBreakdown(from: sheet.round) : nil

        ZStack {
            if !sheet.isReview {
                Color.black.opacity(0.55).ignoresSafeArea(edges: .top)
            }

            VStack(spacing: 0) {
                HStack {
                    Button("　　") {}
                        .foregroundColor(.clear)
                        .disabled(true)
                    Spacer()
                    Text(vm.format.resultTitle(sheet.roundNumber))
                        .accessibilityIdentifier("result.title")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(Color(theme.text))
                    Spacer()
                    Button(tr("編輯")) {
                        if sheet.isReview { vm.editFromReview() } else { vm.editFromResult() }
                    }
                        .accessibilityIdentifier("result.edit")
                        .font(.system(size: 15))
                        .foregroundColor(Color(theme.accentLink))
                }
                .padding(.horizontal, 18)
                .padding(.top, 16)
                .padding(.bottom, 12)

                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(rankingOrder, id: \.self) { index in
                            resultRow(
                                index: index,
                                display: displays[index],
                                breakdown: breakdown.map { vm.format.pairwiseBreakdown($0[index], names: sheet.players) }
                            )
                        }

                        if vm.undoWindow != nil, !sheet.isReview {
                            HStack {
                                Text(tr("入錯咗？"))
                                    .accessibilityIdentifier("result.undoToast")
                                Spacer()
                                Button {
                                    vm.performUndo()
                                } label: {
                                    Text(tr("↶ 撤回"))
                                        .font(.system(size: 14, weight: .bold))
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("result.undo")
                            }
                            .font(.system(size: 14))
                            .foregroundColor(Color(hexResult: 0xCFE0FF))
                            .padding(14)
                            .background(Color(theme.toastBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .padding(.horizontal, 14)
                            .padding(.top, 10)
                        }

                        Text(vm.format.resultTotalsHeader(sheet.roundsCompleted))
                            .accessibilityIdentifier("result.totalsHeader")
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

                    }
                    .padding(.bottom, 8)
                }

                Button {
                    if sheet.isReview { vm.reviewSheet = nil } else { vm.dismissResult() }
                } label: {
                    Text(sheet.isReview ? tr("返回") : tr("下一局"))
                        .font(.system(size: 19, weight: .bold))
                        .foregroundColor(Color(theme.primaryText))
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .background(Color(theme.primary))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(sheet.isReview ? "result.close" : "result.next")
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
            }
            .background(Color(theme.background))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .padding(.top, sheet.isReview ? 0 : 8)
        }
    }

    private func resultRow(index: Int, display: RoundScoreDisplay, breakdown: String?) -> some View {
        let isWinner = display.cardsLeft == 0
        return HStack(spacing: 10) {
            PlayerColorDot(index: index, height: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(isWinner ? "\(sheet.players[index]) 👑" : sheet.players[index])
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(Color(theme.text))
                Text(vm.format.roundDetail(score: display))
                    .font(.system(size: 13))
                    .foregroundColor(Color(theme.secondaryText))
                if let breakdown, !breakdown.isEmpty {
                    Text(breakdown)
                        .font(.system(size: 12))
                        .foregroundColor(Color(theme.secondaryText))
                        .fixedSize(horizontal: false, vertical: true)
                }
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
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("result.row.\(index)")
    }
}

private extension Color {
    init(hexResult: UInt32) {
        self.init(RGBColor(hex: hexResult))
    }
}
