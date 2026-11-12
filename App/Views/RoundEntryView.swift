import SwiftUI
import AppCore
import ScoringEngine

struct RoundEntryView: View {
    @EnvironmentObject private var vm: AppViewModel
    @Environment(\.appTheme) private var theme
    @Binding var sheet: RoundEntrySheet

    @State private var badgeScale: [Int: CGFloat] = [:]
    @State private var lingeringBadge: [Int: Int] = [:]

    var body: some View {
        let session = vm.model.currentSession?.session
        let names = session?.players ?? []
        let roundNumber: Int = {
            switch sheet.mode {
            case .new:
                return (session?.roundsCompleted ?? 0) + 1
            case .edit(let index, _):
                return index + 1
            }
        }()

        VStack(spacing: 0) {
            header(roundNumber: roundNumber)

            Text(sheet.state.hintText(in: vm.region))
                .font(.system(size: 13))
                .foregroundColor(Color(theme.secondaryText))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 18)
                .padding(.bottom, 8)

            ForEach(0..<ScoringEngine.playerCount, id: \.self) { index in
                playerRow(index: index, name: names.indices.contains(index) ? names[index] : vm.format.placeholderName(at: index))
            }

            Spacer(minLength: 8)

            padSection(names: names)
            BannerAdContainer(adsRemoved: vm.model.data.adsRemoved)
        }
        .background(Color(theme.background).ignoresSafeArea())
        .keepAwake(true)
        .onChange(of: sheet.state.pendingBadge) { badge in
            guard let badge else { return }
            presentBadge(badge)
        }
        .onChange(of: sheet.state.justCompleted) { completed in
            if completed {
                vm.handleEntryChange()
            }
        }
        .overlay {
            if let result = vm.resultSheet {
                RoundResultView(sheet: result)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: vm.resultSheet != nil)
    }

    private func header(roundNumber: Int) -> some View {
        HStack {
            Button(tr("✕ 取消")) { vm.cancelRoundEntry() }
                .font(.system(size: 15))
                .foregroundColor(Color(theme.accentLink))
            Spacer()
            Text(vm.format.roundTitle(roundNumber))
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(Color(theme.text))
            Spacer()
            Text("　　")
                .font(.system(size: 15))
                .foregroundColor(.clear)
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    private func playerRow(index: Int, name: String) -> some View {
        let cards = sheet.state.cards[index]
        let isWinner = cards == 0
        let isFocused = sheet.state.focusedIndex == index && vm.resultSheet == nil
        let multiplier = cards.flatMap { sheet.state.multiplier(forCardsLeft: $0) } ?? 1
        let badgeMultiplier = lingeringBadge[index] ?? ((cards != nil && cards != 0 && multiplier >= 2) ? multiplier : nil)

        return HStack(spacing: 10) {
            PlayerColorDot(index: index)
            Text(name)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(Color(theme.text))
                .lineLimit(1)
            Spacer(minLength: 4)
            Button {
                sheet.state.markWinner(index)
                syncLingeringBadges()
            } label: {
                Text(tr("贏"))
                    .font(.system(size: 15, weight: isWinner ? .bold : .regular))
                    .foregroundColor(isWinner ? Color(theme.primaryText) : Color(theme.secondaryText))
                    .frame(width: 62, height: 42)
                    .background(isWinner ? Color(theme.primary) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(isWinner ? Color(theme.primary) : Color(theme.winButtonBorder), lineWidth: 2)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)

            countView(cards: cards, isWinner: isWinner, isFocused: isFocused, badgeMultiplier: badgeMultiplier, scale: badgeScale[index] ?? 1)
        }
        .padding(.horizontal, 12)
        .frame(height: 66)
        .background(Color(isFocused ? theme.cardElevated : theme.card))
        .overlay(
            RoundedRectangle(cornerRadius: theme.cardCornerRadius, style: .continuous)
                .stroke(isFocused ? Color.white : Color.clear, lineWidth: 2)
        )
        .clipShape(RoundedRectangle(cornerRadius: theme.cardCornerRadius, style: .continuous))
        .padding(.horizontal, 14)
        .padding(.vertical, 5)
        .contentShape(Rectangle())
        .onTapGesture {
            sheet.state.selectPlayer(index)
        }
    }

    @ViewBuilder
    private func countView(cards: Int?, isWinner: Bool, isFocused: Bool, badgeMultiplier: Int?, scale: CGFloat) -> some View {
        HStack(spacing: 4) {
            if isWinner {
                Text(tr("出清 👑"))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color(theme.primary))
            } else if let cards {
                Text("\(cards)")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(Color(theme.text))
                if let badgeMultiplier, badgeMultiplier >= 2 {
                    ChaoBadgeView(multiplier: badgeMultiplier, scale: scale)
                }
            } else if isFocused && sheet.state.winnerIndex != nil {
                Text("?")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(Color(theme.tertiaryText))
            } else {
                Text("–")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(Color(theme.tertiaryText))
            }
        }
        .frame(minWidth: 84, minHeight: 42)
        .background(
            Group {
                if isWinner {
                    Color.clear
                } else if cards == nil {
                    Color(theme.countUnsetBackground)
                } else {
                    Color(theme.countSetBackground)
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func padSection(names: [String]) -> some View {
        let enabled = sheet.state.winnerIndex != nil && vm.resultSheet == nil
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(sheet.state.padPrompt(playerNames: names, region: vm.region))
                Spacer()
                Text(tr("顏色 = 炒倍"))
            }
            .font(.system(size: 13))
            .foregroundColor(Color(theme.secondaryText))
            .padding(.bottom, 8)

            NumberPad(
                state: sheet.state,
                onEnter: { value in
                    sheet.state.enterCards(value)
                },
                onUndo: {
                    sheet.state.undo()
                    syncLingeringBadges()
                },
                onClear: {
                    sheet.state.clearFocusedOrAll()
                    syncLingeringBadges()
                }
            )
            .opacity(enabled ? 1 : 0.35)
            .allowsHitTesting(enabled)

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

    private func presentBadge(_ badge: RoundEntryState.ChaoBadge) {
        lingeringBadge[badge.playerIndex] = badge.multiplier
        if vm.model.data.hapticsEnabled {
            ChaoHaptics.play(multiplier: badge.multiplier)
        }
        guard vm.model.data.chaoAnimationEnabled else {
            _ = sheet.state.consumePendingBadge()
            return
        }
        badgeScale[badge.playerIndex] = badge.multiplier >= 4 ? 1.85 : 1.6
        withAnimation(.spring(response: 0.35, dampingFraction: 0.52)) {
            badgeScale[badge.playerIndex] = 1
        }
        _ = sheet.state.consumePendingBadge()
    }

    private func syncLingeringBadges() {
        var next: [Int: Int] = [:]
        for (index, cards) in sheet.state.cards.enumerated() {
            if let cards, cards > 0, let multiplier = sheet.state.multiplier(forCardsLeft: cards), multiplier >= 2 {
                next[index] = multiplier
            }
        }
        lingeringBadge = next
    }
}
