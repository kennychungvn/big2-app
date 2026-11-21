import SwiftUI
import AppCore

private struct AppThemeKey: EnvironmentKey {
    static let defaultValue: Theme = .make(skin: .classic)
}

extension EnvironmentValues {
    var appTheme: Theme {
        get { self[AppThemeKey.self] }
        set { self[AppThemeKey.self] = newValue }
    }
}

extension Color {
    init(_ rgb: RGBColor) {
        self.init(.sRGB, red: rgb.red, green: rgb.green, blue: rgb.blue, opacity: rgb.alpha)
    }
}

extension ShapeStyle where Self == Color {
    static func app(_ rgb: RGBColor) -> Color { Color(rgb) }
}

extension Theme {
    var colorScheme: ColorScheme { isDark ? .dark : .light }
}

enum ThemeFont {
    static func title(_ theme: Theme, size: CGFloat, weight: Font.Weight = .bold) -> Font {
        if let name = theme.titleFontName {
            return .custom(name, size: size).weight(weight)
        }
        return .system(size: size, weight: weight, design: .default)
    }

    static func body(_ theme: Theme, size: CGFloat, weight: Font.Weight = .regular) -> Font {
        if let name = theme.bodyFontName {
            return .custom(name, size: size).weight(weight)
        }
        return .system(size: size, weight: weight, design: .default)
    }

    /// `fontNumber`: every score, count, keypad digit and ×N. Classic = SF Pro with
    /// monospaced digits, Ledger = SF Mono, so columns never jitter.
    static func numeric(_ theme: Theme, size: CGFloat, weight: Font.Weight = .bold) -> Font {
        if theme.monoNumbers {
            return .system(size: size, weight: weight, design: .monospaced)
        }
        return .system(size: size, weight: weight, design: .default).monospacedDigit()
    }

    /// `fontSectionLabel`: Classic SF Pro 13, Ledger SF Mono 13.
    static func sectionLabel(_ theme: Theme, size: CGFloat = 13) -> Font {
        .system(size: size, weight: .regular, design: theme.monoNumbers ? .monospaced : .default)
    }
}

/// Card surface: fill + radius + optional 1pt `line` border (Ledger) + optional 2pt
/// inset `sel` stroke for the selected state (works with or without the border).
struct ThemedCard: ViewModifier {
    let theme: Theme
    var radius: Double?
    var fill: RGBColor?
    var selected: Bool = false
    var selectedColor: RGBColor?

    func body(content: Content) -> some View {
        let r = CGFloat(radius ?? theme.cardCornerRadius)
        let shape = RoundedRectangle(cornerRadius: r, style: .continuous)
        return content
            .background(Color(fill ?? theme.card))
            .clipShape(shape)
            .overlay(
                shape.strokeBorder(Color(theme.line), lineWidth: CGFloat(theme.cardBorderWidth))
            )
            .overlay(
                shape.strokeBorder(Color(selectedColor ?? theme.sel), lineWidth: selected ? 2 : 0)
            )
    }
}

extension View {
    func themedCard(_ theme: Theme, radius: Double? = nil, fill: RGBColor? = nil, selected: Bool = false, selectedColor: RGBColor? = nil) -> some View {
        modifier(ThemedCard(theme: theme, radius: radius, fill: fill, selected: selected, selectedColor: selectedColor))
    }

    /// Grouped-list row styling for Settings-style lists.
    func themedListRow(_ theme: Theme) -> some View {
        listRowBackground(Color(theme.card))
            .listRowSeparatorTint(Color(theme.line))
    }
}

/// Press feedback without delaying the action (motion spec).
struct PressStyle: ButtonStyle {
    var amount: CGFloat = 0.94
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion && MotionSettings.enabled ? amount : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

extension Theme {
    /// Motion-spec default spring (經典 soft with a tiny overshoot; Ledger critically damped).
    var defaultSpring: Animation {
        .spring(response: springResponse, dampingFraction: springDamping)
    }

    /// Motion-spec ease: Classic `.easeOut`, Ledger the crisp 0.2/0/0/1 curve.
    func easeOut(duration: Double) -> Animation {
        if skin == .ledger {
            return .timingCurve(0.2, 0, 0, 1, duration: duration)
        }
        return .easeOut(duration: duration)
    }

    func emptyFanStrokeWidth(isOuter: Bool) -> CGFloat {
        CGFloat(isOuter ? emptyFanStrokeOuter : emptyFanStrokeInner)
    }
}

/// 動畫效果 master switch, mirrored from AppData.chaoAnimationEnabled (same stored value,
/// renamed label) so leaf views can gate motion without the view model.
enum MotionSettings {
    nonisolated(unsafe) static var enabled = true

    static func animation(_ animation: Animation, reduceMotion: Bool) -> Animation? {
        guard enabled else { return nil }
        return reduceMotion ? .easeInOut(duration: 0.15) : animation
    }
}
