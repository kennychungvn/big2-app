import SwiftUI
import AppCore

struct PlayerColorDot: View {
    let index: Int
    var height: CGFloat = 44
    var width: CGFloat = 14

    @Environment(\.appTheme) private var theme

    var body: some View {
        RoundedRectangle(cornerRadius: width / 2, style: .continuous)
            .fill(Color(theme.playerColor(at: index)))
            .frame(width: width, height: height)
    }
}

struct ScoreText: View {
    let value: Int
    var size: CGFloat = 28
    var format: ScoreFormatting = ScoreFormatting()

    @Environment(\.appTheme) private var theme

    var body: some View {
        Text(format.points(value))
            .font(ThemeFont.numeric(size: size, weight: .heavy))
            .foregroundColor(color)
    }

    private var color: Color {
        if value > 0 { return Color(theme.positive) }
        if value < 0 { return Color(theme.negative) }
        return Color(theme.text)
    }
}

struct MoneyText: View {
    let value: Decimal?
    var format: ScoreFormatting = ScoreFormatting()

    @Environment(\.appTheme) private var theme

    var body: some View {
        if let text = format.money(value) {
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(Color(theme.secondaryText))
        }
    }
}
