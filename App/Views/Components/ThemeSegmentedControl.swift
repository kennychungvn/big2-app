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
                                .fill(item == selection ? Color(theme.countSetBackground) : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color(theme.card))
        .clipShape(RoundedRectangle(cornerRadius: theme.textFieldCornerRadius, style: .continuous))
        .padding(.horizontal, 14)
    }
}

struct NameChipRow: View {
    let names: [String]
    let onTap: (String) -> Void

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
                                .foregroundColor(Color(theme.secondaryText))
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(Color(theme.card))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)
            }
        }
    }
}
