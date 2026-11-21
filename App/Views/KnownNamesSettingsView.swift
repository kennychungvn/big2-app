import SwiftUI
import AppCore

/// Manage the 快速填入 name list: swipe to delete and reorder. Does not change past games.
///
/// Native `List` `.onDelete` left the trailing 刪除 action unclipped (it sat outside the
/// inset-grouped card) and, in edit mode, left the confirmation open on the cell that
/// the next name slid into. Both modes now share one clipped card so the action stays
/// inside the rounded frame; confirmation is keyed by name, not row index. In 編輯,
/// the minus and name stay on the left; only the handle yields room for the pill.
struct KnownNamesSettingsView: View {
    @EnvironmentObject private var vm: AppViewModel
    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var editMode: EditMode = .inactive
    @State private var openName: String?
    @State private var confirmingName: String?
    @State private var draggingName: String?
    @State private var dragOffset: CGFloat = 0
    @State private var dragBaseOffset: CGFloat = 0
    @State private var draftNames: [String]?

    private var names: [String] { vm.model.data.knownPlayerNames }
    private var displayedNames: [String] { draftNames ?? names }

    /// Matches iOS inset-grouped section corners (also Ledger's card radius).
    private let groupedCornerRadius: CGFloat = 10
    private let groupedHorizontalPadding: CGFloat = 20
    private let editRowHeight: CGFloat = 44
    fileprivate static let deleteRevealWidth: CGFloat = 88

    var body: some View {
        Group {
            if names.isEmpty && draftNames == nil {
                emptyState
                    .transition(.opacity)
            } else {
                namesCard
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(theme.background).ignoresSafeArea())
        .navigationTitle(tr("管理快速填入名稱"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !names.isEmpty {
                EditButton()
                    .foregroundColor(Color(theme.accentLink))
                    .accessibilityIdentifier("settings.knownNames.edit")
            }
        }
        .toolbarBackground(Color(theme.background), for: .navigationBar)
        .toolbarColorScheme(theme.colorScheme, for: .navigationBar)
        .environment(\.editMode, $editMode)
        .onChange(of: editMode) { mode in
            if mode.isEditing {
                openName = nil
            } else {
                confirmingName = nil
                resetDrag()
            }
        }
        .onChange(of: names) { current in
            if current.isEmpty { editMode = .inactive }
            if let openName, !current.contains(openName) {
                self.openName = nil
            }
            if let confirmingName, !current.contains(confirmingName) {
                self.confirmingName = nil
            }
        }
    }

    private var emptyState: some View {
        Text(tr("未有已儲存嘅名稱"))
            .font(.system(size: 15))
            .foregroundColor(Color(theme.secondaryText))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, groupedHorizontalPadding + 16)
            .padding(.top, 28)
            .accessibilityIdentifier("settings.knownNames.empty")
    }

    /// One clipped rounded card for both swipe-to-delete and edit-mode minus + 刪除,
    /// so the action cannot sit outside the frame. Reorder uses a handle on each row.
    private var namesCard: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(Array(displayedNames.enumerated()), id: \.element) { index, name in
                    row(name: name, index: index, editing: editMode.isEditing)
                        .accessibilityIdentifier(identifier(for: name))
                        .transition(.opacity)
                }
            }
            .animation(rowAnimation, value: displayedNames)
            .background(Color(theme.card))
            .clipShape(RoundedRectangle(cornerRadius: groupedCornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: groupedCornerRadius, style: .continuous)
                    .strokeBorder(Color(theme.line), lineWidth: CGFloat(theme.cardBorderWidth))
            )
            .padding(.horizontal, groupedHorizontalPadding)
            .padding(.top, 20)
            .padding(.bottom, 16)
        }
        .background {
            Color(theme.background)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { dismissConfirm() }
        }
    }

    @ViewBuilder
    private func row(name: String, index: Int, editing: Bool) -> some View {
        let isLast = index == displayedNames.count - 1
        if editing {
            KnownNameEditRow(
                name: name,
                showSeparator: !isLast,
                theme: theme,
                isConfirming: confirmingName == name,
                isDragging: draggingName == name,
                dragOffset: draggingName == name ? dragOffset : 0,
                onToggleConfirm: { toggleConfirm(name) },
                onDismissConfirm: { dismissConfirm() },
                onDelete: { deleteName(name) },
                onDragChanged: { dragChanged(name, $0) },
                onDragEnded: { dragEnded(name) }
            )
        } else {
            KnownNameSwipeRow(
                name: name,
                showSeparator: !isLast,
                theme: theme,
                isOpen: openName == name,
                animation: rowAnimation,
                onOpen: { openRow(name) },
                onClose: { closeRow() },
                onDelete: { deleteName(name) }
            )
        }
    }

    private var rowAnimation: Animation? {
        MotionSettings.animation(.easeOut(duration: 0.25), reduceMotion: reduceMotion)
    }

    private func openRow(_ name: String) {
        withAnimation(rowAnimation) { openName = name }
    }

    private func closeRow() {
        withAnimation(rowAnimation) { openName = nil }
    }

    private func toggleConfirm(_ name: String) {
        withAnimation(rowAnimation) {
            confirmingName = confirmingName == name ? nil : name
        }
    }

    private func dismissConfirm() {
        guard confirmingName != nil else { return }
        withAnimation(rowAnimation) { confirmingName = nil }
    }

    private func deleteName(_ name: String) {
        withAnimation(rowAnimation) {
            vm.removeKnownPlayerName(name)
            if openName == name { openName = nil }
            // Confirmation is keyed by name, so the next row cannot inherit 刪除.
            confirmingName = nil
        }
    }

    private func dragChanged(_ name: String, _ translation: CGFloat) {
        if confirmingName != nil {
            withAnimation(rowAnimation) { confirmingName = nil }
        }
        if draggingName == nil {
            draggingName = name
            draftNames = names
            dragBaseOffset = 0
        }
        guard var order = draftNames, let from = order.firstIndex(of: name) else { return }
        let visual = translation - dragBaseOffset
        let shift = Int((visual / editRowHeight).rounded())
        let newIndex = max(0, min(order.count - 1, from + shift))
        if newIndex != from {
            order.remove(at: from)
            order.insert(name, at: newIndex)
            draftNames = order
            dragBaseOffset += CGFloat(newIndex - from) * editRowHeight
        }
        dragOffset = translation - dragBaseOffset
    }

    private func dragEnded(_ name: String) {
        if let draft = draftNames,
           let to = draft.firstIndex(of: name),
           let from = names.firstIndex(of: name),
           from != to {
            let dest = to > from ? to + 1 : to
            vm.moveKnownPlayerNames(from: IndexSet(integer: from), to: dest)
        }
        withAnimation(rowAnimation) { resetDrag() }
    }

    private func resetDrag() {
        draggingName = nil
        dragOffset = 0
        dragBaseOffset = 0
        draftNames = nil
    }

    private func identifier(for name: String) -> String {
        let index = displayedNames.firstIndex(of: name) ?? 0
        return "settings.knownName.\(index)"
    }
}

// MARK: - Swipe (non-edit)

/// One row of the clipped card: trailing 刪除 is inside the card, so the rounded
/// corners always clip it. Only this row's `isOpen` is true at a time; a delete
/// removes the whole row (button included) so the next row arrives closed.
private struct KnownNameSwipeRow: View {
    let name: String
    let showSeparator: Bool
    let theme: Theme
    let isOpen: Bool
    let animation: Animation?
    let onOpen: () -> Void
    let onClose: () -> Void
    let onDelete: () -> Void

    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false

    private let revealWidth: CGFloat = KnownNamesSettingsView.deleteRevealWidth
    private let fullSwipeDistance: CGFloat = 140

    private var offset: CGFloat {
        let base: CGFloat = isOpen ? -revealWidth : 0
        return min(0, max(-fullSwipeDistance, base + dragOffset))
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            KnownNameDeleteAction(theme: theme, onDelete: onDelete)
                .opacity(offset < -4 ? 1 : 0)
                .allowsHitTesting(isOpen || offset < -revealWidth * 0.5)

            VStack(spacing: 0) {
                Text(name)
                    .foregroundColor(Color(theme.text))
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .padding(.horizontal, 16)

                if showSeparator {
                    Color(theme.line)
                        .frame(height: 1.0 / 3.0)
                        .padding(.leading, 16)
                }
            }
            .background(Color(theme.card))
            .contentShape(Rectangle())
            .offset(x: offset)
            .onTapGesture {
                if isOpen { onClose() }
            }
            .gesture(swipeGesture)
        }
        .frame(minHeight: 44)
        .onChange(of: isOpen) { open in
            if !open && !isDragging {
                dragOffset = 0
            }
        }
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 20, coordinateSpace: .local)
            .onChanged { value in
                let dx = value.translation.width
                let dy = value.translation.height
                guard abs(dx) > abs(dy) else { return }
                if !isDragging {
                    isDragging = true
                    // Close a different open row; do not change this row's isOpen mid-drag.
                    if !isOpen { onClose() }
                }
                // Keep `isOpen` unchanged while dragging so the base offset is stable.
                if isOpen {
                    dragOffset = min(revealWidth, dx)
                } else {
                    dragOffset = min(0, dx)
                }
            }
            .onEnded { value in
                let predicted = value.predictedEndTranslation.width
                let finalOffset = (isOpen ? -revealWidth : 0) + value.translation.width
                isDragging = false
                withAnimation(animation) { dragOffset = 0 }
                if predicted < -fullSwipeDistance || finalOffset < -fullSwipeDistance {
                    onDelete()
                } else if finalOffset < -revealWidth * 0.5 {
                    onOpen()
                } else {
                    onClose()
                }
            }
    }
}

// MARK: - Edit

/// Edit-mode row in the same clipped card: minus + 刪除 + reorder handle.
/// Confirmation is per-name. Unlike swipe-to-delete, the minus and name stay
/// visible on the left; only the trailing handle yields 88 pt so the pill
/// sits inside the card inset (HANDOFF names-delete spec).
private struct KnownNameEditRow: View {
    let name: String
    let showSeparator: Bool
    let theme: Theme
    let isConfirming: Bool
    let isDragging: Bool
    let dragOffset: CGFloat
    let onToggleConfirm: () -> Void
    let onDismissConfirm: () -> Void
    let onDelete: () -> Void
    let onDragChanged: (CGFloat) -> Void
    let onDragEnded: () -> Void

    private let revealWidth: CGFloat = KnownNamesSettingsView.deleteRevealWidth

    var body: some View {
        ZStack(alignment: .trailing) {
            KnownNameDeleteAction(theme: theme, onDelete: onDelete)
                .opacity(isConfirming ? 1 : 0)
                .allowsHitTesting(isConfirming)
                .accessibilityIdentifier(deleteIdentifier)

            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Button(action: onToggleConfirm) {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(Color(theme.destructiveFill))
                            .rotationEffect(.degrees(isConfirming ? 90 : 0))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(tr("刪除"))
                    .accessibilityIdentifier(minusIdentifier)

                    Text(name)
                        .foregroundColor(Color(theme.text))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .onTapGesture { onDismissConfirm() }

                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(theme.secondaryText))
                        .frame(width: 28, height: 44)
                        .contentShape(Rectangle())
                        .gesture(reorderGesture)
                        .accessibilityHidden(true)
                }
                .padding(.leading, 10)
                .padding(.trailing, isConfirming ? 0 : 12)
                .frame(minHeight: 44)

                if showSeparator {
                    Color(theme.line)
                        .frame(height: 1.0 / 3.0)
                        .padding(.leading, 16)
                }
            }
            // Shrink the content, do not offset it: the minus and name stay on the
            // left, the handle shifts, and the 刪除 pill occupies the trailing inset.
            .padding(.trailing, isConfirming ? revealWidth : 0)
            .background(isDragging ? Color(theme.card) : Color.clear)
        }
        .frame(minHeight: 44)
        .offset(y: dragOffset)
        .zIndex(isDragging ? 1 : 0)
    }

    private var reorderGesture: some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .local)
            .onChanged { onDragChanged($0.translation.height) }
            .onEnded { _ in onDragEnded() }
    }

    private var minusIdentifier: String { "settings.knownNames.minus.\(name)" }
    private var deleteIdentifier: String { "settings.knownNames.delete.\(name)" }
}

/// Shared trailing 刪除 pill, inset so the card's rounded corners clip it cleanly.
private struct KnownNameDeleteAction: View {
    let theme: Theme
    let onDelete: () -> Void

    var body: some View {
        Button(action: onDelete) {
            HStack(spacing: 4) {
                Image(systemName: "trash")
                Text(tr("刪除"))
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .frame(maxHeight: .infinity)
            .background(
                Color(theme.destructiveFill),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .padding(.vertical, 6)
        .padding(.trailing, 8)
        .padding(.leading, 8)
        .accessibilityLabel(tr("刪除"))
    }
}
