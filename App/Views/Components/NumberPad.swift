import SwiftUI
import AppCore
import ScoringEngine

struct NumberPad: View {
    let state: RoundEntryState
    /// Called with 0 for the 贏 key, 1...13 for leftover cards.
    var onEnter: (Int) -> Void
    var onUndo: () -> Void

    @Environment(\.appTheme) private var theme

    /// 5 columns × 3 rows: 贏 1 2 3 4 / 5 6 7 8 9 / 10 11 12 13 ↶.
    static let keyHeight: CGFloat = 56

    private let keys: [Key] = {
        var result: [Key] = [.winner]
        result += (1...13).map { .number($0) }
        result.append(.undo)
        return result
    }()

    private enum Key: Hashable {
        case winner
        case number(Int)
        case undo
    }

    var body: some View {
        let selected = focusedValue
        return VStack(alignment: .leading, spacing: 8) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 8) {
                ForEach(keys, id: \.self) { key in
                    padKey(key, selected: selected)
                }
            }
        }
    }

    private var focusedValue: Int? {
        guard let index = state.focusedIndex, state.cards.indices.contains(index) else { return nil }
        return state.cards[index]
    }

    @ViewBuilder
    private func padKey(_ key: Key, selected: Int?) -> some View {
        switch key {
        case .winner:
            let enabled = state.isPadEnabled && state.canEnterWinner
            let isSelected = selected == RoundEntryState.winnerValue && state.isPadEnabled
            Button {
                onEnter(RoundEntryState.winnerValue)
            } label: {
                Text(tr("贏"))
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundColor(Color(theme.primaryText))
                    .frame(maxWidth: .infinity)
                    .frame(height: Self.keyHeight)
                    .background(Color(theme.primary))
                    .clipShape(RoundedRectangle(cornerRadius: theme.keyCornerRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: theme.keyCornerRadius, style: .continuous)
                            .stroke(Color.white, lineWidth: isSelected ? 3 : 0)
                    )
                    .opacity(enabled ? 1 : 0.3)
            }
            .buttonStyle(.plain)
            .disabled(!enabled)
            .accessibilityIdentifier("pad.win")
            .accessibilityLabel(tr("贏"))

        case .number(let value):
            let multiplier = state.multiplier(forCardsLeft: value) ?? 1
            let isSelected = selected == value && state.isPadEnabled
            Button {
                onEnter(value)
            } label: {
                VStack(spacing: 3) {
                    Text("\(value)")
                        .font(.system(size: 24, weight: .bold))
                    if multiplier >= 2 {
                        Text("×\(multiplier)")
                            .font(.system(size: 11, weight: .semibold))
                            .opacity(0.85)
                    }
                }
                .foregroundColor(Color(theme.keyTextColor(forMultiplier: multiplier)))
                .frame(maxWidth: .infinity)
                .frame(height: Self.keyHeight)
                .background(Color(theme.keyColor(forMultiplier: multiplier)))
                .clipShape(RoundedRectangle(cornerRadius: theme.keyCornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: theme.keyCornerRadius, style: .continuous)
                        .stroke(Color.white, lineWidth: isSelected ? 3 : 0)
                )
            }
            .buttonStyle(.plain)
            .disabled(!state.isPadEnabled)
            .accessibilityIdentifier("pad.\(value)")
            .accessibilityLabel(multiplier >= 2 ? tr("%@ 張，炒 %@ 倍", "\(value)", "\(multiplier)") : tr("%@ 張", "\(value)"))

        case .undo:
            Button(action: onUndo) {
                Text("↶")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(Color(theme.secondaryText))
                    .frame(maxWidth: .infinity)
                    .frame(height: Self.keyHeight)
                    .background(Color(theme.keyUtilityBackground))
                    .clipShape(RoundedRectangle(cornerRadius: theme.keyCornerRadius, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!state.canUndo)
            .accessibilityIdentifier("pad.undo")
            .accessibilityLabel(tr("撤回"))

        }
    }
}

/// The same `×N` pill for every 炒倍; fixed width so pills line up across rows.
// TODO: highlight the session's highest 炒倍 with an animation (Kenny, later) — no wording.
struct ChaoBadgeView: View {
    static let width: CGFloat = 30
    let multiplier: Int
    var scale: CGFloat = 1

    @Environment(\.appTheme) private var theme

    var body: some View {
        Text("×\(multiplier)")
            .font(.system(size: 12, weight: .bold))
            .monospacedDigit()
            .foregroundColor(.white)
            .frame(width: Self.width)
            .padding(.vertical, 2)
            .background(Color(theme.badgeColor(forMultiplier: multiplier)))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .scaleEffect(scale)
    }
}
