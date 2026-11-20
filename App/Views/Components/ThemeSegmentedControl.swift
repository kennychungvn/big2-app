import SwiftUI
import AppCore

struct ThemeSegmentedControl<Item: Hashable>: View {
    let items: [Item]
    let title: (Item) -> String
    @Binding var selection: Item

    @Environment(\.appTheme) private var theme

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items, id: \.self) { item in
                Button {
                    selection = item
                } label: {
                    Text(title(item))
                        .font(.system(size: 15, weight: item == selection ? .bold : .regular))
                        .foregroundColor(item == selection ? Color(theme.text) : Color(theme.secondaryText))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(item == selection ? Color(theme.card) : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .themedCard(theme, radius: theme.textFieldCornerRadius, fill: theme.surface2)
        .padding(.horizontal, 16)
    }
}

struct NameChipRow: View {
    let names: [String]
    let onTap: (String) -> Void
    var onDelete: ((String) -> Void)? = nil

    @Environment(\.appTheme) private var theme

    var body: some View {
        if !names.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(names, id: \.self) { name in
                        Button {
                            onTap(name)
                        } label: {
                            Text("+ \(name)")
                                .font(.system(size: 14))
                                .foregroundColor(Color(theme.text))
                                .padding(.horizontal, 12)
                                .frame(height: 32)
                                .background(Color(theme.surface2))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("setup.chip.\(name)")
                        .contextMenu {
                            if let onDelete {
                                Button(role: .destructive) {
                                    onDelete(name)
                                } label: {
                                    Label(tr("刪除"), systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
}
