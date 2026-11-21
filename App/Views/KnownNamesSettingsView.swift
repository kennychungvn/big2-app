import SwiftUI
import AppCore

/// Manage the 快速填入 name list: swipe to delete and reorder. Does not change past games.
///
/// Native `List` `.onDelete` left three visual glitches: the trailing action stayed open
/// as the next row slid into the same cell, the red button's square corner poked out of
/// the inset-grouped card, and deleting the last row squashed the button into a blob
/// with a blank row lingering before the empty state. Default mode uses a clipped card
/// with a controlled swipe so those cannot happen. Edit mode still uses `List` for
/// reorder (and the standard minus-delete).
struct KnownNamesSettingsView: View {
    @EnvironmentObject private var vm: AppViewModel
    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var editMode: EditMode = .inactive
    @State private var openName: String?

    private var names: [String] { vm.model.data.knownPlayerNames }

    /// Matches iOS inset-grouped section corners (also Ledger's card radius).
    private let groupedCornerRadius: CGFloat = 10
    private let groupedHorizontalPadding: CGFloat = 20

    var body: some View {
        Group {
            if names.isEmpty {
                emptyState
                    .transition(.opacity)
            } else if editMode.isEditing {
                editList
                    .transition(.opacity)
            } else {
                swipeCard
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
            if mode.isEditing { openName = nil }
        }
        .onChange(of: names) { current in
            if current.isEmpty { editMode = .inactive }
            if let openName, !current.contains(openName) {
                self.openName = nil
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

    /// Standard inset-grouped list used only while 編輯 is on, so reorder stays native.
    private var editList: some View {
        List {
            ForEach(Array(names.enumerated()), id: \.element) { _, name in
                Text(name)
                    .foregroundColor(Color(theme.text))
                    .themedListRow(theme)
                    .accessibilityIdentifier(identifier(for: name))
            }
            .onDelete { delete(at: $0) }
            .onMove { vm.moveKnownPlayerNames(from: $0, to: $1) }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(theme.background).ignoresSafeArea())
    }

    private var swipeCard: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(Array(names.enumerated()), id: \.element) { index, name in
                    KnownNameSwipeRow(
                        name: name,
                        showSeparator: index < names.count - 1,
                        theme: theme,
                        isOpen: openName == name,
                        animation: rowAnimation,
                        onOpen: { openRow(name) },
                        onClose: { closeRow() },
                        onDelete: { deleteName(name) }
                    )
                    .accessibilityIdentifier(identifier(for: name))
                    .transition(.opacity)
                }
            }
            .animation(rowAnimation, value: names)
            .background(Color(theme.card))
            .clipShape(RoundedRectangle(cornerRadius: groupedCornerRadius, style: .continuous))
            .padding(.horizontal, groupedHorizontalPadding)
            .padding(.top, 20)
            .padding(.bottom, 16)
        }
        .background(Color(theme.background).ignoresSafeArea())
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

    private func deleteName(_ name: String) {
        withAnimation(rowAnimation) {
            vm.removeKnownPlayerName(name)
            if openName == name { openName = nil }
        }
    }

    private func delete(at offsets: IndexSet) {
        withAnimation(rowAnimation) {
            vm.removeKnownPlayerNames(at: offsets)
        }
    }

    private func identifier(for name: String) -> String {
        let index = names.firstIndex(of: name) ?? 0
        return "settings.knownName.\(index)"
    }
}

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

    private let revealWidth: CGFloat = 88
    private let fullSwipeDistance: CGFloat = 140

    private var offset: CGFloat {
        let base: CGFloat = isOpen ? -revealWidth : 0
        return min(0, max(-fullSwipeDistance, base + dragOffset))
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            deleteAction
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

    private var deleteAction: some View {
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
