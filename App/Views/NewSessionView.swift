import SwiftUI
import AppCore
import ScoringEngine

struct NewSessionView: View {
    @EnvironmentObject private var vm: AppViewModel
    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var draft: NewSessionDraft

    init(settings: LastSettings) {
        _draft = State(initialValue: NewSessionDraft(from: settings))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    sectionTitle("玩家（㩒下面名一下就填）")

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

                    sectionTitle("計分規則")
                    ThemeSegmentedControl(
                        items: RulePreset.allCases,
                        title: { $0.displayName },
                        selection: $draft.preset
                    )
                    Text(draft.preset.summary)
                        .font(.system(size: 13))
                        .foregroundColor(Color(theme.secondaryText))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(Color(theme.historyRow))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .padding(.horizontal, 14)
                        .padding(.top, 6)

                    sectionTitle("每分幾錢（可選）")
                    ThemeSegmentedControl(
                        items: MoneyChip.allCases,
                        title: { $0.title },
                        selection: moneyChipBinding
                    )

                    if draft.pointValue.isCustom {
                        HStack {
                            Text("$")
                                .foregroundColor(Color(theme.secondaryText))
                            TextField("例如 0.5", text: $draft.customAmountText)
                                .keyboardType(.decimalPad)
                                .foregroundColor(Color(theme.text))
                                .tint(Color(theme.primary))
                        }
                        .padding(.horizontal, 12)
                        .frame(height: 54)
                        .background(Color(theme.card))
                        .clipShape(RoundedRectangle(cornerRadius: theme.textFieldCornerRadius, style: .continuous))
                        .padding(.horizontal, 14)
                        .padding(.top, 8)
                    }
                }
                .padding(.bottom, 24)
            }
            .background(Color(theme.background).ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                PrimaryButton(title: "開始 ▶", enabled: draft.canStart) {
                    vm.startSession(from: draft)
                }
                .padding(.vertical, 12)
                .background(Color(theme.background).opacity(0.96))
            }
            .navigationTitle("新開一場")
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

    private enum MoneyChip: String, CaseIterable, Hashable {
        case none, one, two, five, custom

        var title: String {
            switch self {
            case .none: return "唔計"
            case .one: return "$1"
            case .two: return "$2"
            case .five: return "$5"
            case .custom: return "自訂"
            }
        }

        var option: PointValueOption {
            switch self {
            case .none: return .none
            case .one: return .one
            case .two: return .two
            case .five: return .five
            case .custom: return .custom(0)
            }
        }

        init(option: PointValueOption) {
            switch option {
            case .none: self = .none
            case .one: self = .one
            case .two: self = .two
            case .five: self = .five
            case .custom: self = .custom
            }
        }
    }

    private var moneyChipBinding: Binding<MoneyChip> {
        Binding(
            get: { MoneyChip(option: draft.pointValue) },
            set: { chip in
                if chip == .custom {
                    draft.pointValue = .custom(draft.resolvedPointValue ?? 0)
                } else {
                    draft.pointValue = chip.option
                }
            }
        )
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
