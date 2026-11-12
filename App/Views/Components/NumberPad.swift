import SwiftUI
import AppCore
import ScoringEngine

struct NumberPad: View {
    let state: RoundEntryState
    var onEnter: (Int) -> Void
    var onUndo: () -> Void
    var onClear: () -> Void

    @Environment(\.appTheme) private var theme

    private let keys: [Key] = {
        var result: [Key] = (1...13).map { .number($0) }
        result.append(.undo)
        result.append(.clear)
        return result
    }()

    private enum Key: Hashable {
        case number(Int)
        case undo
        case clear
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
                .foregroundColor(Color(theme.text))
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(Color(theme.keyColor(forMultiplier: multiplier)))
                .clipShape(RoundedRectangle(cornerRadius: theme.keyCornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: theme.keyCornerRadius, style: .continuous)
                        .stroke(Color.white, lineWidth: isSelected ? 3 : 0)
                )
            }
            .buttonStyle(.plain)
            .disabled(!state.isPadEnabled)
            .accessibilityLabel(multiplier >= 2 ? "\(value) 張，炒 \(multiplier) 倍" : "\(value) 張")

        case .undo:
            Button(action: onUndo) {
                Text("↶")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(Color(theme.secondaryText))
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .background(Color(theme.keyUtilityBackground))
                    .clipShape(RoundedRectangle(cornerRadius: theme.keyCornerRadius, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!state.canUndo)
            .accessibilityLabel("撤回")

        case .clear:
            Button(action: onClear) {
                Text("清除")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color(theme.secondaryText))
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .background(Color(theme.keyUtilityBackground))
                    .clipShape(RoundedRectangle(cornerRadius: theme.keyCornerRadius, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("清除")
        }
    }
}

struct ChaoBadgeView: View {
    let multiplier: Int
    var scale: CGFloat = 1

    @Environment(\.appTheme) private var theme

    var body: some View {
        Text(multiplier >= 4 ? "炒到盡！×\(multiplier)" : "×\(multiplier)")
            .font(.system(size: multiplier >= 4 ? 13 : 12, weight: .bold))
            .foregroundColor(.white)
            .padding(.vertical, 2)
            .padding(.horizontal, 6)
            .background(Color(theme.badgeColor(forMultiplier: multiplier)))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .scaleEffect(scale)
    }
}
