import SwiftUI
import AppCore
import ScoringEngine

/// Taiwan-only 入牌 screen: pick a winner, enter leftover cards, tap 「+×2」 for each
/// unplayed 2 / 4條 / 同花順, then 確定. Follows the approved entry mockup (通吃 wording).
struct TaiwanRoundEntryView: View {
    @EnvironmentObject private var vm: AppViewModel
    @Environment(\.appTheme) private var theme
    @Binding var sheet: RoundEntrySheet

    var body: some View {
        let session = vm.model.currentSession?.session
        let names = session?.players ?? []
        let mode = session?.scoringMode ?? .winnerTakesAll
        let roundNumber: Int = {
            switch sheet.mode {
            case .new:
                return (session?.roundsCompleted ?? 0) + 1
            case .edit(let index, _, _):
                return index + 1
            }
        }()

        VStack(spacing: 0) {
            header(roundNumber: roundNumber, mode: mode)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text(tr("先點選贏家，再為其他玩家輸入剩餘張數。"))
                        .font(.system(size: 13))
                        .foregroundColor(Color(theme.secondaryText))
                        .padding(.horizontal, 18)
                    Text(tr("未出的 2 或 4 條／同花順，請點「×2」手動加倍。"))
                        .font(.system(size: 13))
                        .foregroundColor(Color(theme.secondaryText))
                        .padding(.horizontal, 18)
                        .padding(.top, 2)
                        .padding(.bottom, 12)
                        .accessibilityIdentifier("entry.hint")

                    ForEach(0..<ScoringEngine.playerCount, id: \.self) { index in
                        playerCard(
                            index: index,
                            name: names.indices.contains(index) ? names[index] : vm.format.placeholderName(at: index),
                            mode: mode
                        )
                    }

                    totals(names: names, mode: mode)
                        .padding(.horizontal, 18)
                        .padding(.top, 8)
                        .padding(.bottom, 12)
                }
            }

            padAndConfirm(names: names)
        }
        .background(Color(theme.background).ignoresSafeArea())
        .keepAwake(true)
        .onChange(of: sheet.state.justCompleted) { completed in
            if completed { vm.handleEntryChange() }
        }
        .overlay {
            if let result = vm.resultSheet {
                RoundResultView(sheet: result)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: vm.resultSheet != nil)
        .bannerSlot()
    }

    private func header(roundNumber: Int, mode: ScoringMode) -> some View {
        VStack(spacing: 8) {
            HStack {
                Button(tr("✕ 取消")) { vm.cancelRoundEntry() }
                    .accessibilityIdentifier("entry.cancel")
                    .font(.system(size: 15))
                    .foregroundColor(Color(theme.accentLink))
                Spacer()
                Text(vm.format.roundTitle(roundNumber))
                    .accessibilityIdentifier("entry.title")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(Color(theme.text))
                Spacer()
                Text("　　")
                    .font(.system(size: 15))
                    .foregroundColor(.clear)
            }
            .padding(.horizontal, 18)

            Text(mode == .winnerTakesAll ? tr("台灣玩法 • 贏家通吃") : tr("台灣玩法 • 互對"))
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color(theme.primaryText))
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Color(theme.primary))
                .clipShape(Capsule())
                .accessibilityIdentifier("entry.modeBadge")
        }
        .padding(.top, 8)
        .padding(.bottom, 10)
    }

    private func playerCard(index: Int, name: String, mode: ScoringMode) -> some View {
        let cards = sheet.state.cards[index]
        let isWinner = cards == 0
        let isFocused = sheet.state.focusedIndex == index && vm.resultSheet == nil
        let doubles = sheet.state.manualDoubles[index]
        let base = cards.flatMap { sheet.state.multiplier(forCardsLeft: $0) } ?? 1
        let penalty = sheet.state.livePenalty(at: index)

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                PlayerColorDot(index: index)
                Text(name)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Color(theme.text))
                    .lineLimit(1)
                Spacer(minLength: 4)
                if isWinner {
                    HStack(spacing: 4) {
                        Text("🏆")
                        Text(tr("贏家"))
                            .font(.system(size: 15, weight: .bold))
                    }
                    .foregroundColor(Color(theme.primary))
                    .accessibilityIdentifier("entry.winner.\(index)")
                } else if let cards {
                    Text("\(cards)")
                        .font(.system(size: 22, weight: .bold))
                        .monospacedDigit()
                        .foregroundColor(Color(theme.text))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Color(theme.countSetBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                } else if isFocused {
                    Text("?")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(Color(theme.tertiaryText))
                } else {
                    Text("–")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(Color(theme.tertiaryText))
                }
            }

            if isWinner {
                Text(mode == .winnerTakesAll
                     ? tr("本局通吃，收取其餘玩家全部分數")
                     : tr("依分數差額與其他玩家互相結算"))
                    .font(.system(size: 13))
                    .foregroundColor(Color(theme.secondaryText))
            } else if let cards, let penalty {
                Text(formula(cards: cards, base: base, doubles: doubles, value: penalty))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(theme.text))
                    .accessibilityIdentifier("entry.formula.\(index)")

                HStack(alignment: .center, spacing: 8) {
                    Text(doubleCaption(doubles))
                        .font(.system(size: 13))
                        .foregroundColor(Color(theme.secondaryText))
                    Spacer()
                    doubleStepper(index: index, doubles: doubles)
                }
            }
        }
        .padding(14)
        .background(Color(isFocused ? theme.cardElevated : theme.card))
        .overlay(
            RoundedRectangle(cornerRadius: theme.cardCornerRadius, style: .continuous)
                .stroke(
                    isWinner ? Color(theme.primary).opacity(0.85) : (isFocused ? Color.white : Color.clear),
                    lineWidth: isWinner || isFocused ? 1.5 : 0
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: theme.cardCornerRadius, style: .continuous))
        .padding(.horizontal, 14)
        .padding(.vertical, 5)
        .contentShape(Rectangle())
        .onTapGesture { sheet.state.selectPlayer(index) }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("entry.row.\(index)")
    }

    private func formula(cards: Int, base: Int, doubles: Int, value: Int) -> AttributedString {
        var text = AttributedString(vm.format.penaltyFormula(cardsLeft: cards, baseMultiplier: base, manualDoubles: doubles))
        // Color the equals value: the last token after " = ".
        if let range = text.range(of: "= \(value)") {
            text[range].foregroundColor = Color(theme.primary)
            text[range].font = .system(size: 14, weight: .bold)
        }
        return text
    }

    private func doubleCaption(_ doubles: Int) -> String {
        if doubles == 0 { return tr("尚未加倍") }
        if doubles == 1 { return tr("加倍") }
        return tr("加倍 %@ 次", "\(doubles)")
    }

    private func doubleStepper(index: Int, doubles: Int) -> some View {
        HStack(spacing: 6) {
            Button {
                sheet.state.decrementDoubles(at: index)
            } label: {
                Text("−")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color(theme.secondaryText))
                    .frame(width: 36, height: 32)
                    .background(Color(theme.countUnsetBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(doubles == 0)
            .opacity(doubles == 0 ? 0.4 : 1)
            .accessibilityIdentifier("entry.double.dec.\(index)")

            ForEach(0..<doubles, id: \.self) { chip in
                Text("×2")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color(theme.primaryText))
                    .padding(.horizontal, 8)
                    .frame(height: 28)
                    .background(Color(theme.keyColor(forMultiplier: 2)))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .accessibilityHidden(true)
                    .id("dbl-\(index)-\(chip)")
            }

            Button {
                sheet.state.incrementDoubles(at: index)
                if vm.model.data.hapticsEnabled {
                    ChaoHaptics.play(multiplier: 2)
                }
            } label: {
                Text(tr("+ ×2"))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color(theme.primaryText))
                    .padding(.horizontal, 10)
                    .frame(height: 32)
                    .background(Color(theme.primary))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(doubles >= ScoringEngine.maxManualDoubles)
            .accessibilityIdentifier("entry.double.inc.\(index)")
        }
    }

    @ViewBuilder
    private func totals(names: [String], mode: ScoringMode) -> some View {
        if let total = sheet.state.liveWinnerTakesAllTotal, sheet.state.isComplete {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(tr("本局合計"))
                        .foregroundColor(Color(theme.secondaryText))
                    Spacer()
                    Text("\(total)")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(Color(theme.text))
                        .accessibilityIdentifier("entry.total")
                }
                if mode == .winnerTakesAll, let winner = sheet.state.winnerIndex {
                    let name = names.indices.contains(winner) ? names[winner] : vm.format.placeholderName(at: winner)
                    HStack {
                        Text(tr("贏家 %@ 通吃", name))
                            .foregroundColor(Color(theme.secondaryText))
                        Spacer()
                        Text(vm.format.points(total))
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(Color(theme.positive))
                    }
                }
            }
            .font(.system(size: 15))
        }
    }

    private func padAndConfirm(names: [String]) -> some View {
        // Once every seat is filled, hide the pad (as in the mockup) so the ×2
        // steppers and 確定 stay on screen. Tapping a row brings the pad back.
        let padVisible = sheet.state.focusedIndex != nil && vm.resultSheet == nil
        return VStack(spacing: 10) {
            if padVisible {
                Text(sheet.state.padPrompt(playerNames: names, region: .taiwan))
                    .accessibilityIdentifier("entry.prompt")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .font(.system(size: 13))
                    .foregroundColor(Color(theme.secondaryText))

                NumberPad(
                    state: sheet.state,
                    onEnter: { value in
                        sheet.state.enterCards(value)
                    },
                    onUndo: {
                        sheet.state.undo()
                    }
                )
            }

            PrimaryButton(title: tr("確定"), enabled: sheet.state.canConfirm && vm.resultSheet == nil) {
                sheet.state.confirm()
            }
            .accessibilityIdentifier("entry.confirm")

            AdSafeGap()
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .background(Color(theme.padBackground))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
        }
    }
}
