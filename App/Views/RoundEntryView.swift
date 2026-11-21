import SwiftUI
import AppCore
import ScoringEngine

struct RoundEntryView: View {
    @EnvironmentObject private var vm: AppViewModel
    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var sheet: RoundEntrySheet

    @State private var badgeScale: [Int: CGFloat] = [:]

    var body: some View {
        #if TAIWAN
        TaiwanRoundEntryView(sheet: $sheet)
        #else
        hongKongBody
        #endif
    }

    @ViewBuilder
    private var hongKongBody: some View {
        let session = vm.model.currentSession?.session
        let names = session?.players ?? []
        let roundNumber: Int = {
            switch sheet.mode {
            case .new:
                return (session?.roundsCompleted ?? 0) + 1
            case .edit(let index, _, _):
                return index + 1
            }
        }()

        VStack(spacing: 0) {
            header(roundNumber: roundNumber)

            Text(sheet.state.hintText(in: vm.region))
                .accessibilityIdentifier("entry.hint")
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
        // Own banner (the full-screen cover hides the root one), outside the result
        // overlay so the RoundResult sheet never covers it.
        .bannerSlot()
    }

    private func header(roundNumber: Int) -> some View {
        HStack {
            Button(tr("✕ 取消")) { vm.cancelRoundEntry() }
                .accessibilityIdentifier("entry.cancel")
                .font(.system(size: 15))
                .foregroundColor(Color(theme.accentLink))
            Spacer()
            Text(vm.format.roundTitle(roundNumber))
                .accessibilityIdentifier("entry.title")
                .font(.system(size: 17, weight: .semibold))
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
        let badgeMultiplier = sheet.state.displayedBadgeMultiplier(at: index)

        return HStack(spacing: 10) {
            PlayerColorDot(index: index)
            Text(name)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(Color(theme.text))
                .lineLimit(1)
            Spacer(minLength: 4)
            countView(cards: cards, isWinner: isWinner, isFocused: isFocused, badgeMultiplier: badgeMultiplier, scale: badgeScale[index] ?? 1)
        }
        .padding(.horizontal, 12)
        .frame(height: 62)
        .themedCard(
            theme,
            selected: isFocused || isWinner,
            selectedColor: isFocused ? theme.sel : theme.hi
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            sheet.state.selectPlayer(index)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("entry.row.\(index)")
    }

    /// Same width on every row so the pills line up. Sized for "13" + gap + ×N at full
    /// font size, plus padding so the 1.6× badge pop (`scaleEffect`, layout-neutral)
    /// cannot overlap the digits. Comfortable on iPhone SE (375 pt) as well as larger phones.
    private enum CountPill {
        static let width: CGFloat = 104
        static let height: CGFloat = 42
        static let numberWidth: CGFloat = 36
        static let spacing: CGFloat = 12
        static let horizontalPadding: CGFloat = 12
    }

    @ViewBuilder
    private func countView(cards: Int?, isWinner: Bool, isFocused: Bool, badgeMultiplier: Int?, scale: CGFloat) -> some View {
        HStack(spacing: CountPill.spacing) {
            if isWinner {
                Text(tr("出晒 👑"))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color(theme.hi))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(theme.hiSoft))
                    .clipShape(Capsule())
            } else if let cards {
                Text("\(cards)")
                    .font(ThemeFont.numeric(theme, size: 20, weight: .bold))
                    .foregroundColor(Color(theme.text))
                    .lineLimit(1)
                    .frame(width: CountPill.numberWidth, alignment: .trailing)
                if let badgeMultiplier, badgeMultiplier >= 2 {
                    ChaoBadgeView(multiplier: badgeMultiplier, scale: scale)
                } else {
                    Color.clear.frame(width: ChaoBadgeView.width, height: 1)
                }
            } else if isFocused {
                Text("?")
                    .font(ThemeFont.numeric(theme, size: 20, weight: .bold))
                    .foregroundColor(Color(theme.tertiaryText))
            } else {
                Text("–")
                    .font(ThemeFont.numeric(theme, size: 20, weight: .bold))
                    .foregroundColor(Color(theme.tertiaryText))
            }
        }
        .padding(.horizontal, CountPill.horizontalPadding)
        .frame(width: CountPill.width, height: CountPill.height)
        .layoutPriority(1)
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
        .clipShape(RoundedRectangle(cornerRadius: theme.keyCornerRadius, style: .continuous))
    }

    private func padSection(names: [String]) -> some View {
        let enabled = sheet.state.isPadEnabled && vm.resultSheet == nil
        return VStack(alignment: .leading, spacing: 0) {
            Text(sheet.state.padPrompt(playerNames: names, region: vm.region))
                .accessibilityIdentifier("entry.prompt")
                .frame(maxWidth: .infinity, alignment: .leading)
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
                }
            )
            .opacity(enabled ? 1 : 0.35)
            .allowsHitTesting(enabled)

            AdSafeGap()
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .background(Color(theme.padBackground))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color(theme.line))
                .frame(height: 1)
        }
    }

    private func presentBadge(_ badge: RoundEntryState.ChaoBadge) {
        if vm.model.data.hapticsEnabled {
            ChaoHaptics.play(multiplier: badge.multiplier)
        }
        guard vm.model.data.chaoAnimationEnabled, !reduceMotion else {
            _ = sheet.state.consumePendingBadge()
            return
        }
        // 炒倍 stamp (motion §8): ×N tag scales 1.25 → 1 with the skin spring, non-blocking.
        badgeScale[badge.playerIndex] = 1.25
        withAnimation(theme.monoNumbers ? .spring(response: 0.25, dampingFraction: 1.0) : .spring(response: 0.3, dampingFraction: 0.75)) {
            badgeScale[badge.playerIndex] = 1
        }
        _ = sheet.state.consumePendingBadge()
    }

}
