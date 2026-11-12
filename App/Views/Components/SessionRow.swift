import SwiftUI
import AppCore

/// One row in 最近場次 / 所有紀錄: date · rounds on the left, leader or 未打完 on the right.
struct SessionRow: View {
    let stored: StoredSession
    let action: () -> Void

    @EnvironmentObject private var vm: AppViewModel
    @Environment(\.appTheme) private var theme

    var body: some View {
        Button(action: action) {
            HStack {
                Text(vm.format.sessionListSubtitle(date: stored.endedAt ?? stored.updatedAt, rounds: stored.session.roundsCompleted))
                    .foregroundColor(Color(theme.text))
                Spacer()
                if stored.isFinished, let leader = stored.leaderSummary(format: vm.format) {
                    let leadingPoints = stored.session.ranking.first?.total ?? 0
                    Text(leader)
                        .foregroundColor(leadingPoints >= 0 ? Color(theme.positive) : Color(theme.negative))
                } else if !stored.isFinished {
                    Text(tr("未打完"))
                        .foregroundColor(Color(theme.secondaryText))
                }
            }
            .font(.system(size: 15))
            .padding(.horizontal, 12)
            .frame(height: 54)
            .background(Color(theme.card))
            .clipShape(RoundedRectangle(cornerRadius: theme.textFieldCornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 14)
        .padding(.vertical, 5)
    }
}
