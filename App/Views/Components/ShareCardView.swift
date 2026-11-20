import SwiftUI
import AppCore

struct ShareCardView: View {
    let summary: ShareSummary
    var theme: Theme = .neighbourhood

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 10) {
                Text(summary.title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Color(theme.text))
                    .padding(.trailing, summary.conversionLine == nil ? 0 : 88)
                Text("\(summary.dateLine) · \(summary.roundsLine)")
                    .font(.system(size: 15))
                    .foregroundColor(Color(theme.secondaryText))
                Text(summary.ruleLine)
                    .font(.system(size: 13))
                    .foregroundColor(Color(theme.secondaryText))
                VStack(spacing: 6) {
                    ForEach(Array(summary.rows.enumerated()), id: \.offset) { _, row in
                        HStack {
                            Text("\(row.rank). \(row.isLeader ? "👑 " : "")\(row.name)")
                                .font(.system(size: 17, weight: row.isLeader ? .bold : .regular))
                                .foregroundColor(Color(theme.text))
                            Spacer()
                            score(for: row)
                        }
                        .padding(.vertical, row.originalPoints == nil ? 8 : 10)
                        .padding(.horizontal, 12)
                        .themedCard(theme, radius: theme.keyCornerRadius)
                    }
                }
                .padding(.top, 8)
            }
            .padding(24)

            if let conversionLine = summary.conversionLine {
                Text(conversionLine)
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundColor(Color(theme.primaryText))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color(theme.primary))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .padding(.top, 20)
                    .padding(.trailing, 20)
                    .accessibilityIdentifier("share.conversionTag")
            }
        }
        .frame(width: 390, alignment: .leading)
        .background(Color(theme.background))
        .environment(\.colorScheme, theme.colorScheme)
    }

    @ViewBuilder
    private func score(for row: ShareSummary.Row) -> some View {
        if let original = row.originalPoints {
            VStack(alignment: .trailing, spacing: 3) {
                Text(row.points)
                    .font(ThemeFont.numeric(theme, size: 24, weight: .heavy))
                    .foregroundColor(pointsColor(row.points))
                Text(original)
                    .font(ThemeFont.numeric(theme, size: 12, weight: .semibold))
                    .foregroundColor(Color(theme.secondaryText))
            }
        } else {
            Text(row.points)
                .font(ThemeFont.numeric(theme, size: 17, weight: .bold))
                .foregroundColor(pointsColor(row.points))
        }
    }

    private func pointsColor(_ points: String) -> Color {
        if points.hasPrefix("+") { return Color(theme.positive) }
        if points.hasPrefix("−") { return Color(theme.negative) }
        return Color(theme.text)
    }
}
