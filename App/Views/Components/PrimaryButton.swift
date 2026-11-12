import SwiftUI
import AppCore

struct PrimaryButton: View {
    let title: String
    var height: CGFloat = 64
    var fontSize: CGFloat = 22
    var enabled: Bool = true
    let action: () -> Void

    @Environment(\.appTheme) private var theme

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: fontSize, weight: .heavy))
                .foregroundColor(Color(theme.primaryText))
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .background(Color(theme.primary).opacity(enabled ? 1 : 0.4))
                .clipShape(RoundedRectangle(cornerRadius: theme.buttonCornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .padding(.horizontal, 18)
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
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(Color(theme.text))
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(Color(theme.secondaryText))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 76)
            .background(Color(theme.card))
            .clipShape(RoundedRectangle(cornerRadius: theme.buttonCornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 18)
    }
}
