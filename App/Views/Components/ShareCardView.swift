import SwiftUI
import AppCore

struct ShareCardView: View {
    let summary: ShareSummary
    var theme: Theme = .neighbourhood

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(summary.title)
                .font(.system(size: 26, weight: .heavy))
                .foregroundColor(Color(theme.text))
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
                        Text(row.points)
                            .font(ThemeFont.numeric(size: 17, weight: .bold))
                            .foregroundColor(row.points.hasPrefix("+") ? Color(theme.positive) : (row.points.hasPrefix("−") ? Color(theme.negative) : Color(theme.text)))
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color(theme.historyRow))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            .padding(.top, 8)
        }
        .padding(24)
        .frame(width: 390, alignment: .leading)
        .background(Color(theme.background))
    }
}
