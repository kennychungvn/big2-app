import SwiftUI
import AppCore
import ScoringEngine

struct NewSessionView: View {
    @EnvironmentObject private var vm: AppViewModel
    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var draft: NewSessionDraft

    init(draft: NewSessionDraft) {
        _draft = State(initialValue: draft)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    sectionTitle(tr("玩家（㩒下面名一下就填）"))

                    ForEach(0..<ScoringEngine.playerCount, id: \.self) { index in
                        HStack(spacing: 10) {
                            PlayerColorDot(index: index, height: 30)
                            TextField(vm.format.placeholderName(at: index), text: $draft.names[index])
                                .font(.system(size: 18))
                                .foregroundColor(Color(theme.text))
                                .tint(Color(theme.primary))
                        }
                        .padding(.horizontal, 12)
                        .frame(height: 54)
                        .background(Color(theme.card))
                        .clipShape(RoundedRectangle(cornerRadius: theme.textFieldCornerRadius, style: .continuous))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 5)
                    }

                    NameChipRow(names: vm.model.availableNameChips(for: draft.names)) { name in
                        _ = draft.applyChip(name)
                    }
                    .padding(.top, 4)

                    sectionTitle(tr("計分規則"))
                    ThemeSegmentedControl(
                        items: vm.region.rulePresets,
                        title: { $0.displayName(in: vm.region) },
                        selection: $draft.preset
                    )
                    Text(draft.preset.summary(in: vm.region))
                        .font(.system(size: 13))
                        .foregroundColor(Color(theme.secondaryText))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(Color(theme.historyRow))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .padding(.horizontal, 14)
                        .padding(.top, 6)
                }
                .padding(.bottom, 24)
            }
            .background(Color(theme.background).ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                PrimaryButton(title: tr("開始 ▶"), enabled: draft.canStart) {
                    vm.startSession(from: draft)
                }
                .padding(.vertical, 12)
                .background(Color(theme.background).opacity(0.96))
            }
            .navigationTitle(tr("新開一場"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("✕") { dismiss() }
                        .foregroundColor(Color(theme.accentLink))
                }
            }
            .toolbarBackground(Color(theme.background), for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundColor(Color(theme.secondaryText))
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 6)
    }
}
