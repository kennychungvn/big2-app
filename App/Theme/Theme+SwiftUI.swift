import SwiftUI
import AppCore

private struct AppThemeKey: EnvironmentKey {
    static let defaultValue: Theme = .neighbourhood
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

    static func numeric(size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}
