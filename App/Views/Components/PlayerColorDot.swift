import SwiftUI
import AppCore

/// Player marker (`marker` token): Classic capsule (5×24 at full size), Ledger 9pt square.
struct PlayerColorDot: View {
    let index: Int
    var height: CGFloat = 24
    var width: CGFloat = 5

    @Environment(\.appTheme) private var theme

    var body: some View {
        if theme.squareMarker {
            let side = min(9, max(height, width))
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Color(theme.playerColor(at: index)))
                .frame(width: side, height: side)
        } else {
            Capsule(style: .continuous)
                .fill(Color(theme.playerColor(at: index)))
                .frame(width: min(width, 5), height: min(height, 24))
        }
    }
}

struct ScoreText: View {
    let value: Int
    var size: CGFloat = 28
    var format: ScoreFormatting = ScoreFormatting()

    @Environment(\.appTheme) private var theme

    var body: some View {
        Text(format.points(value))
            .font(ThemeFont.numeric(theme, size: size, weight: .heavy))
            .foregroundColor(color)
    }

    private var color: Color {
        if value > 0 { return Color(theme.positive) }
        if value < 0 { return Color(theme.negative) }
        return Color(theme.text)
    }
}
