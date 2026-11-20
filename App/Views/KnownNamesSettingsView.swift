import SwiftUI
import AppCore

/// Manage the 快速填入 name list: swipe to delete and reorder. Does not change past games.
struct KnownNamesSettingsView: View {
    @EnvironmentObject private var vm: AppViewModel
    @Environment(\.appTheme) private var theme

    var body: some View {
        List {
            if vm.model.data.knownPlayerNames.isEmpty {
                Text(tr("未有已儲存嘅名稱"))
                    .font(.system(size: 15))
                    .foregroundColor(Color(theme.secondaryText))
                    .listRowBackground(Color(theme.background))
                    .accessibilityIdentifier("settings.knownNames.empty")
            } else {
                ForEach(vm.model.data.knownPlayerNames, id: \.self) { name in
                    Text(name)
                        .foregroundColor(Color(theme.text))
                        .themedListRow(theme)
                        .accessibilityIdentifier(identifier(for: name))
                }
                .onDelete { vm.removeKnownPlayerNames(at: $0) }
                .onMove { vm.moveKnownPlayerNames(from: $0, to: $1) }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color(theme.background).ignoresSafeArea())
        .navigationTitle(tr("管理快速填入名稱"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !vm.model.data.knownPlayerNames.isEmpty {
                EditButton()
                    .foregroundColor(Color(theme.accentLink))
                    .accessibilityIdentifier("settings.knownNames.edit")
            }
        }
        .toolbarBackground(Color(theme.background), for: .navigationBar)
        .toolbarColorScheme(theme.colorScheme, for: .navigationBar)
    }

    private func identifier(for name: String) -> String {
        let index = vm.model.data.knownPlayerNames.firstIndex(of: name) ?? 0
        return "settings.knownName.\(index)"
    }
}
