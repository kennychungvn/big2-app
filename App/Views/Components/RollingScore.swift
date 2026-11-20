import SwiftUI
import AppCore

/// One-shot count-up for a signed total (motion spec §4 / §5).
///
/// Interpolates `value` when the parent animates it. Colour follows the
/// in-flight number and flips at 0. Never loops: no `repeatForever`,
/// `TimelineView`, or timer.
struct RollingScore: View, Animatable {
    var value: Double
    var size: CGFloat = 28
    var format: ScoreFormatting = ScoreFormatting()
    var weight: Font.Weight = .heavy

    @Environment(\.appTheme) private var theme

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    private var displayed: Int { Int(value.rounded()) }

    var body: some View {
        Text(format.points(displayed))
            .font(ThemeFont.numeric(theme, size: size, weight: weight))
            .foregroundColor(color)
            .accessibilityHidden(true)
    }

    private var color: Color {
        if displayed > 0 { return Color(theme.positive) }
        if displayed < 0 { return Color(theme.negative) }
        return Color(theme.text)
    }
}

/// Running-total presentation. The model value is the source of truth and is
/// never delayed; only this display rolls.
///
/// - Motion on, Reduce Motion off: 450 ms ease-out (Ledger: crisp), 40 ms
///   stagger per `column`, then stop.
/// - Reduce Motion: 150 ms crossfade, no interpolation.
/// - 動畫效果 off: instant swap.
struct RollingScoreText: View {
    let value: Int
    var size: CGFloat = 28
    var format: ScoreFormatting = ScoreFormatting()
    var weight: Font.Weight = .heavy
    /// 0-based column / position for the 40 ms stagger.
    var column: Int = 0
    /// When set (and different from `value`), the first appearance rolls from
    /// this number. Otherwise the first frame snaps to `value` (no roll-from-0).
    var appearFrom: Int? = nil

    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var displayed: Double
    @State private var shownValue: Int
    @State private var didAppear = false

    init(
        value: Int,
        size: CGFloat = 28,
        format: ScoreFormatting = ScoreFormatting(),
        weight: Font.Weight = .heavy,
        column: Int = 0,
        appearFrom: Int? = nil
    ) {
        self.value = value
        self.size = size
        self.format = format
        self.weight = weight
        self.column = column
        self.appearFrom = appearFrom
        let start = appearFrom ?? value
        _displayed = State(initialValue: Double(start))
        _shownValue = State(initialValue: start)
    }

    var body: some View {
        Group {
            if shouldInterpolate {
                RollingScore(value: displayed, size: size, format: format, weight: weight)
            } else {
                Text(format.points(shownValue))
                    .font(ThemeFont.numeric(theme, size: size, weight: weight))
                    .foregroundColor(staticColor)
                    .id(shownValue)
                    .transition(.opacity)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityLabel(format.points(value))
        .onAppear {
            guard !didAppear else { return }
            didAppear = true
            if let appearFrom, appearFrom != value, shouldInterpolate {
                displayed = Double(appearFrom)
                animateInterpolation(to: value)
            } else {
                snap(to: value, fade: shouldCrossfade && appearFrom != nil && appearFrom != value)
            }
        }
        .onChange(of: value) { newValue in
            guard didAppear else { return }
            if shouldInterpolate {
                animateInterpolation(to: newValue)
            } else {
                snap(to: newValue, fade: shouldCrossfade)
            }
        }
    }

    private var shouldInterpolate: Bool {
        MotionSettings.enabled && !reduceMotion
    }

    private var shouldCrossfade: Bool {
        MotionSettings.enabled && reduceMotion
    }

    private var staticColor: Color {
        if shownValue > 0 { return Color(theme.positive) }
        if shownValue < 0 { return Color(theme.negative) }
        return Color(theme.text)
    }

    private func animateInterpolation(to target: Int) {
        let curve: Animation = theme.monoNumbers
            ? .timingCurve(0.2, 0, 0, 1, duration: 0.45)
            : .easeOut(duration: 0.45)
        withAnimation(curve.delay(Double(column) * 0.04)) {
            displayed = Double(target)
        }
    }

    private func snap(to target: Int, fade: Bool) {
        displayed = Double(target)
        if fade {
            withAnimation(.easeInOut(duration: 0.15)) {
                shownValue = target
            }
        } else {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                shownValue = target
            }
        }
    }
}
