import SwiftUI
import UIKit
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
                    nameSectionHeader

                    ForEach(0..<ScoringEngine.playerCount, id: \.self) { index in
                        nameField(index: index)
                    }

                    let chips = vm.model.availableNameChips(for: draft.names)
                    if !chips.isEmpty {
                        sectionTitle(tr("㩒名快速填入"))
                        NameChipRow(names: chips, onTap: { name in
                            _ = draft.applyChip(name)
                        }, onDelete: { name in
                            vm.removeKnownPlayerName(name)
                        })
                    }

                    if AppFlavor.current.isTaiwanApp {
                        taiwanModeSection
                    } else {
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
            .onReceive(NotificationCenter.default.publisher(for: UITextField.textDidBeginEditingNotification)) { notification in
                selectAll(in: notification.object as? UITextField)
            }
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

    private var nameSectionHeader: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(tr("玩家"))
                .font(.system(size: 13))
                .foregroundColor(Color(theme.secondaryText))
            Spacer()
            Button(tr("清除全部")) {
                draft.clearAllNames()
                focusedField = nil
            }
            .font(.system(size: 13))
            .foregroundColor(Color(theme.accentLink))
            .disabled(!draft.hasAnyName)
            .opacity(draft.hasAnyName ? 1 : 0.4)
            .accessibilityIdentifier("setup.clearAll")
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 6)
    }

    private func nameField(index: Int) -> some View {
        HStack(spacing: 10) {
            PlayerColorDot(index: index, height: 30)
            TextField(
                vm.format.placeholderName(at: index),
                text: $draft.names[index],
                onEditingChanged: { isEditing in
                    if isEditing { selectAllInFocusedField() }
                }
            )
            .accessibilityIdentifier("setup.name.\(index)")
            .focused($focusedField, equals: index)
            .submitLabel(index < ScoringEngine.playerCount - 1 ? .next : .done)
            .onSubmit {
                focusedField = index < ScoringEngine.playerCount - 1 ? index + 1 : nil
            }
            .font(.system(size: 18))
            .foregroundColor(Color(theme.text))
            .tint(Color(theme.primary))
            if !draft.names[index].isEmpty {
                Button {
                    draft.names[index] = ""
                } label: {
                    Text("✕")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color(theme.secondaryText))
                        .frame(width: 28, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tr("清除"))
                .accessibilityIdentifier("setup.name.clear.\(index)")
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 54)
        .background(Color(theme.card))
        .clipShape(RoundedRectangle(cornerRadius: theme.textFieldCornerRadius, style: .continuous))
        .padding(.horizontal, 14)
        .padding(.vertical, 5)
    }

    private func selectAllInFocusedField() {
        DispatchQueue.main.async {
            UIApplication.shared.sendAction(#selector(UIResponder.selectAll(_:)), to: nil, from: nil, for: nil)
        }
    }

    private func selectAll(in field: UITextField?) {
        guard let field else { return }
        DispatchQueue.main.async {
            field.selectedTextRange = field.textRange(from: field.beginningOfDocument, to: field.endOfDocument)
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


    private var taiwanModeSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionTitle(tr("計分方式"))
                .padding(.top, 8)

            HStack(spacing: 8) {
                modeChip(title: tr("贏家通吃"), selected: draft.scoringMode == .winnerTakesAll, id: "setup.mode.winnerTakesAll") {
                    draft.scoringMode = .winnerTakesAll
                }
                modeChip(title: tr("互對"), selected: draft.scoringMode == .pairwise, id: "setup.mode.pairwise") {
                    draft.scoringMode = .pairwise
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 10)

            Text(draft.scoringMode == .winnerTakesAll
                 ? tr("贏家通吃：其餘玩家依剩餘張數與門檻計算，全數給贏家。")
                 : tr("互對：每兩位玩家依計算後分數的差額互相結算。"))
                .font(.system(size: 13))
                .foregroundColor(Color(theme.secondaryText))
                .padding(.horizontal, 18)
                .padding(.bottom, 16)
                .accessibilityIdentifier("setup.modeHint")

            sectionTitle(tr("加倍門檻"))
            Text(tr("1–7 張固定 ×1。"))
                .font(.system(size: 13))
                .foregroundColor(Color(theme.secondaryText))
                .padding(.horizontal, 18)
            Text(tr("預設 8 張起 ×2、10 張起 ×3、13 張 ×4，點格可調整。"))
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
    }

    private func modeChip(title: String, selected: Bool, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(selected ? Color(theme.primaryText) : Color(theme.secondaryText))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(selected ? Color(theme.cardElevated) : Color(theme.card))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
