import SwiftUI
import AppCore

/// 所有紀錄: sessions with at least one round, unfinished ones on top (▶ 繼續), grouped under
/// date headers (今日 / 昨日 / 11/14). Tapping a row opens it on top of this list; swipe left
/// to delete (with a confirm).
struct AllSessionsView: View {
    @EnvironmentObject private var vm: AppViewModel
    @Environment(\.appTheme) private var theme
    @State private var pendingDelete: StoredSession?

    var body: some View {
        let sections = vm.format.sections(for: vm.model.allSessions)
        let positions = Dictionary(
            uniqueKeysWithValues: vm.model.allSessions.enumerated().map { ($0.element.id, $0.offset) }
        )
        List {
            ForEach(sections) { section in
                Text(section.title)
                    .font(ThemeFont.sectionLabel(theme))
                    .foregroundColor(Color(theme.secondaryText))
                    .padding(.horizontal, 18)
                    .padding(.top, 12)
                    .padding(.bottom, 2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color(theme.background))
                    .listRowSeparator(.hidden)
                    .accessibilityAddTraits(.isHeader)

                ForEach(section.sessions) { stored in
                    SessionRow(stored: stored) {
                        vm.openSession(stored, push: true)
                    }
                    .accessibilityIdentifier("all.row.\(positions[stored.id] ?? 0)")
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color(theme.background))
                    .listRowSeparator(.hidden)
                    // Not role: .destructive — that removes the row before the confirm.
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button {
                            pendingDelete = stored
                        } label: {
                            Label(tr("刪除"), systemImage: "trash")
                        }
                        .tint(Color(theme.negative))
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.defaultMinListRowHeight, 1)
        .padding(.vertical, 4)
        .background(Color(theme.background).ignoresSafeArea())
        .deleteSessionAlert(pending: $pendingDelete) { vm.deleteSession($0.id) }
        .navigationTitle(tr("所有紀錄"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(theme.background), for: .navigationBar)
        .toolbarColorScheme(theme.colorScheme, for: .navigationBar)
    }
}
