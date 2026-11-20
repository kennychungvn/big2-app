import SwiftUI
import AppCore

/// One row in 最近場次 / 所有紀錄 (v1.1 design B).
/// Line 1: `14:05 · 4 局` on the left; `🏆 winner +score` (bold green, ties `曦、肥 +80`) on the
/// right, or a yellow `▶ 繼續` badge for an unfinished session. Line 2: the remaining players,
/// high to low, green positive / red negative (unfinished sessions list all four).
struct SessionRow: View {
    let stored: StoredSession
    /// Home has no date headers, so its rows start with `今日` / `昨日` / `11/14`.
    var showsDay: Bool = false
    /// Inside a grouped card (home 最近場次): no own card / outer padding.
    var grouped: Bool = false
    let action: () -> Void

    @EnvironmentObject private var vm: AppViewModel
    @Environment(\.appTheme) private var theme

    var body: some View {
        let summary = SessionListSummary(stored: stored)
        Button(action: action) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(title(summary))
                        .font(.system(size: 16))
                        .foregroundColor(Color(theme.text))
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    trailing(summary)
                }
                if !summary.others.isEmpty {
                    othersLine(summary.others)
                        .font(.system(size: 13))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .modifier(SessionRowCard(theme: theme, grouped: grouped))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, grouped ? 0 : 16)
        .padding(.vertical, grouped ? 0 : 4)
    }

    private func title(_ summary: SessionListSummary) -> String {
        if showsDay {
            return vm.format.sessionRowTitleWithDay(date: stored.listDate, rounds: summary.rounds)
        }
        return vm.format.sessionRowTitle(date: stored.listDate, rounds: summary.rounds)
    }

    @ViewBuilder
    private func trailing(_ summary: SessionListSummary) -> some View {
        if !summary.isFinished {
            Text(tr("▶ 繼續"))
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color(theme.primaryText))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color(theme.primary))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .accessibilityIdentifier("session.continueBadge")
        } else if let line = summary.winnerLine(format: vm.format), let total = summary.winningTotal {
            Text(line)
                .font(ThemeFont.numeric(theme, size: 17, weight: .bold))
                .foregroundColor(color(for: total))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    /// `肥 +20 · 權 −60 · 南 −90`: names grey, numbers green / red.
    private func othersLine(_ scores: [SessionListScore]) -> Text {
        var text = Text("")
        for (offset, score) in scores.enumerated() {
            if offset > 0 {
                text = text + Text(" · ").foregroundColor(Color(theme.secondaryText))
            }
            text = text
                + Text("\(score.name) ").foregroundColor(Color(theme.secondaryText))
                + Text(vm.format.points(score.total)).foregroundColor(color(for: score.total))
        }
        return text
    }

    private func color(for total: Int) -> Color {
        if total > 0 { return Color(theme.positive) }
        if total < 0 { return Color(theme.negative) }
        return Color(theme.secondaryText)
    }
}

private struct SessionRowCard: ViewModifier {
    let theme: Theme
    let grouped: Bool

    func body(content: Content) -> some View {
        if grouped {
            content
        } else {
            content.themedCard(theme)
        }
    }
}

/// Confirm before a history row is deleted (所有紀錄 swipe, 最近場次 long-press).
struct DeleteSessionAlert: ViewModifier {
    @Binding var pending: StoredSession?
    let onDelete: (StoredSession) -> Void

    func body(content: Content) -> some View {
        content.alert(
            tr("刪除呢場紀錄？"),
            isPresented: Binding(
                get: { pending != nil },
                set: { if !$0 { pending = nil } }
            ),
            presenting: pending
        ) { stored in
            Button(tr("取消"), role: .cancel) { pending = nil }
            Button(tr("刪除"), role: .destructive) {
                onDelete(stored)
                pending = nil
            }
        } message: { stored in
            Text(tr("%@ 嘅分數會一齊刪除，刪咗就救唔返。", stored.playerSummary))
        }
    }
}

extension View {
    func deleteSessionAlert(pending: Binding<StoredSession?>, onDelete: @escaping (StoredSession) -> Void) -> some View {
        modifier(DeleteSessionAlert(pending: pending, onDelete: onDelete))
    }
}
