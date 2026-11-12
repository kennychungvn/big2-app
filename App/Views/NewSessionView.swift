import SwiftUI
import AppCore
import ScoringEngine

struct NewSessionView: View {
    @EnvironmentObject private var vm: AppViewModel
    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var draft: NewSessionDraft
    @FocusState private var focusedField: Int?

    init(draft: NewSessionDraft) {
        _draft = State(initialValue: draft)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    sectionTitle(tr("玩家"))

                    ForEach(0..<ScoringEngine.playerCount, id: \.self) { index in
                        HStack(spacing: 10) {
                            PlayerColorDot(index: index, height: 30)
                            TextField(vm.format.placeholderName(at: index), text: $draft.names[index])
                                .accessibilityIdentifier("setup.name.\(index)")
                                .focused($focusedField, equals: index)
                                .submitLabel(index < ScoringEngine.playerCount - 1 ? .next : .done)
                                .onSubmit {
                                    focusedField = index < ScoringEngine.playerCount - 1 ? index + 1 : nil
                                }
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

                    let chips = vm.model.availableNameChips(for: draft.names)
                    if !chips.isEmpty {
                        sectionTitle(tr("㩒名快速填入"))
                        NameChipRow(names: chips) { name in
                            _ = draft.applyChip(name)
                        }
                    }

                    sectionTitle(tr("炒法"))
                        .padding(.top, 8)
                    Text(tr("1-7 張固定 ×1，㩒格轉倍數（×1 至 ×4）"))
                        .font(.system(size: 13))
                        .foregroundColor(Color(theme.secondaryText))
                        .padding(.horizontal, 18)
                        .padding(.bottom, 8)

                    HStack(spacing: 6) {
                        ForEach(Array(ChaoTable.editableCounts), id: \.self) { cards in
                            chaoTile(cards: cards)
                        }
                    }
                    .padding(.horizontal, 14)

                    if draft.usesRememberedChao {
                        Text(tr("已幫你填好上次用嘅炒法"))
                            .font(.system(size: 13))
                            .foregroundColor(Color(theme.secondaryText))
                            .padding(.horizontal, 18)
                            .padding(.top, 10)
                    }
                }
                .padding(.bottom, 24)
            }
            .background(Color(theme.background).ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    if !draft.canStart {
                        Text(tr("要填齊 4 個玩家名先開到"))
                            .accessibilityIdentifier("setup.namesHint")
                            .font(.system(size: 13))
                            .foregroundColor(Color(theme.negative))
                    }
                    PrimaryButton(title: tr("開波 ▶"), enabled: draft.canStart) {
                        vm.startSession(from: draft)
                    }
                    .accessibilityIdentifier("setup.start")
                }
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(Color(theme.background).opacity(0.96))
            }
            .navigationTitle(tr("新開一場"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("✕") { dismiss() }
                        .accessibilityIdentifier("setup.close")
                        .foregroundColor(Color(theme.accentLink))
                }
            }
            .toolbarBackground(Color(theme.background), for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    private func chaoTile(cards: Int) -> some View {
        let multiplier = draft.chaoTable.multiplier(forCards: cards)
        let foreground = Color(theme.keyTextColor(forMultiplier: multiplier))
        return Button {
            draft.cycleMultiplier(cards: cards)
            if vm.model.data.hapticsEnabled {
                ChaoHaptics.play(multiplier: draft.chaoTable.multiplier(forCards: cards))
            }
        } label: {
            VStack(spacing: 2) {
                Text(tr("%@張", "\(cards)"))
                    .font(.system(size: 12, weight: .medium))
                    .opacity(0.85)
                Text("×\(multiplier)")
                    .font(.system(size: 22, weight: .heavy))
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
            }
            .foregroundColor(foreground)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(Color(theme.keyColor(forMultiplier: multiplier)))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("setup.tile.\(cards)")
        .accessibilityValue("×\(multiplier)")
        .accessibilityLabel(tr("%@ 張，炒 %@ 倍", "\(cards)", "\(multiplier)"))
        .accessibilityHint(tr("㩒格轉倍數"))
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
