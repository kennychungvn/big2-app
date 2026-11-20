import SwiftUI
import AppCore

struct PrimaryButton: View {
    let title: String
    var height: CGFloat = 56
    var fontSize: CGFloat = 18
    var enabled: Bool = true
    let action: () -> Void

    @Environment(\.appTheme) private var theme

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: fontSize, weight: theme.monoNumbers ? .semibold : .bold))
                // Disabled: the shared disabled look (surface2 fill, secondary text) in both
                // skins, instead of a faded accent (Ledger white-on-pale-blue was 2:1).
                .foregroundColor(Color(enabled ? theme.primaryText : theme.secondaryText))
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .background(Color(enabled ? theme.primary : theme.surface2))
                .clipShape(RoundedRectangle(cornerRadius: theme.buttonCornerRadius, style: .continuous))
        }
        .buttonStyle(PressStyle(amount: 0.97))
        .disabled(!enabled)
        .padding(.horizontal, 16)
        .accessibilityAddTraits(.isButton)
    }
}

struct SecondaryButton: View {
    let title: String
    var subtitle: String? = nil
    let action: () -> Void

    @Environment(\.appTheme) private var theme

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Color(theme.text))
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(Color(theme.secondaryText))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: subtitle == nil ? 48 : 64)
            .themedCard(theme, radius: theme.buttonCornerRadius, fill: theme.surface2)
        }
        .buttonStyle(PressStyle(amount: 0.97))
        .padding(.horizontal, 16)
    }
}
