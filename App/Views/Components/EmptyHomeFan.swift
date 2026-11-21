import SwiftUI
import AppCore

/// Option C 花色版: four outline ♠♥♣♦ cards in the app-icon line style, drawn in
/// SwiftUI so they can deal in (HANDOFF §4 01a, motion-spec §10).
struct EmptyHomeFan: View {
    let theme: Theme
    /// When true, cards sit at the rest fan. When false, they stack at the centre, 8 pt down.
    var atRest: Bool

    private let artboard = CGSize(width: 340, height: 140)
    private let cardSize = CGSize(width: 72, height: 102)
    private let restAnchors: [CGPoint] = [
        CGPoint(x: 68, y: 134),
        CGPoint(x: 136, y: 134),
        CGPoint(x: 204, y: 134),
        CGPoint(x: 272, y: 134),
    ]
    private let restAngles: [Double] = [-10, -3.5, 3.5, 10]
    private let stackAnchor = CGPoint(x: 170, y: 142)
    private let pips: [SuitPip] = [.spade, .heart, .club, .diamond]

    var body: some View {
        ZStack {
            ForEach(Array(pips.enumerated()), id: \.offset) { index, pip in
                let isOuter = index == 0 || index == 3
                let anchor = atRest ? restAnchors[index] : stackAnchor
                let angle = atRest ? restAngles[index] : 0
                SuitFanCard(pip: pip, theme: theme, isOuter: isOuter)
                    .frame(width: cardSize.width, height: cardSize.height)
                    .rotationEffect(.degrees(angle), anchor: .bottom)
                    .position(x: anchor.x, y: anchor.y - cardSize.height / 2)
                    .animation(dealAnimation(index: index), value: atRest)
            }
        }
        .frame(width: artboard.width, height: artboard.height)
        .frame(maxWidth: .infinity)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .accessibilityIdentifier("home.emptyFan")
    }

    private func dealAnimation(index: Int) -> Animation? {
        guard MotionSettings.enabled else { return nil }
        return theme.defaultSpring.delay(Double(index) * 0.08)
    }
}

/// One 72×102 outline card with a centred filled pip, scale 0.44, copied from
/// `home-empty/_html/C-classic.html` / `C-ledger.html`.
private struct SuitFanCard: View {
    let pip: SuitPip
    let theme: Theme
    let isOuter: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        let stroke = theme.emptyFanStrokeWidth(isOuter: isOuter)
        shape
            .fill(Color(theme.emptyFanFill))
            .overlay(
                shape.stroke(Color(theme.hi), style: StrokeStyle(lineWidth: stroke, lineJoin: .round))
            )
            .overlay(alignment: .topLeading) {
                SuitPipShape(pip: pip)
                    .fill(Color(theme.hi))
                    .frame(width: 100, height: 110)
                    .scaleEffect(0.44, anchor: .topLeading)
                    // HTML: translate(cardX + 14, cardY + 29) scale(0.44) on the native path.
                    .offset(x: 14, y: 29)
            }
            .frame(width: 72, height: 102)
    }
}

private enum SuitPip {
    case spade, heart, club, diamond
}

/// Icon-style filled suit paths from the option-C HTML sources. Coordinates are
/// the original 100×~110 drawing space; the card applies scale 0.44.
private struct SuitPipShape: Shape {
    var pip: SuitPip

    func path(in _: CGRect) -> Path {
        switch pip {
        case .spade: return spade
        case .heart: return heart
        case .club: return club
        case .diamond: return diamond
        }
    }

    private var spade: Path {
        var path = Path()
        path.move(to: CGPoint(x: 50, y: 4))
        path.addCurve(to: CGPoint(x: 8, y: 62), control1: CGPoint(x: 38, y: 22), control2: CGPoint(x: 8, y: 40))
        path.addCurve(to: CGPoint(x: 33, y: 86), control1: CGPoint(x: 8, y: 77), control2: CGPoint(x: 20, y: 86))
        path.addCurve(to: CGPoint(x: 47, y: 79), control1: CGPoint(x: 40, y: 86), control2: CGPoint(x: 45, y: 83))
        path.addCurve(to: CGPoint(x: 36, y: 97), control1: CGPoint(x: 46, y: 87), control2: CGPoint(x: 42, y: 93))
        path.addLine(to: CGPoint(x: 64, y: 97))
        path.addCurve(to: CGPoint(x: 53, y: 79), control1: CGPoint(x: 58, y: 93), control2: CGPoint(x: 54, y: 87))
        path.addCurve(to: CGPoint(x: 67, y: 86), control1: CGPoint(x: 55, y: 83), control2: CGPoint(x: 60, y: 86))
        path.addCurve(to: CGPoint(x: 92, y: 62), control1: CGPoint(x: 80, y: 86), control2: CGPoint(x: 92, y: 77))
        path.addCurve(to: CGPoint(x: 50, y: 4), control1: CGPoint(x: 92, y: 40), control2: CGPoint(x: 62, y: 22))
        path.closeSubpath()
        return path
    }

    private var heart: Path {
        var path = Path()
        path.move(to: CGPoint(x: 50, y: 91))
        path.addCurve(to: CGPoint(x: 8, y: 38), control1: CGPoint(x: 48, y: 88), control2: CGPoint(x: 8, y: 63))
        path.addCurve(to: CGPoint(x: 34, y: 11), control1: CGPoint(x: 8, y: 22), control2: CGPoint(x: 20, y: 11))
        path.addCurve(to: CGPoint(x: 50, y: 26), control1: CGPoint(x: 43, y: 11), control2: CGPoint(x: 48, y: 17))
        path.addCurve(to: CGPoint(x: 66, y: 11), control1: CGPoint(x: 52, y: 17), control2: CGPoint(x: 57, y: 11))
        path.addCurve(to: CGPoint(x: 92, y: 38), control1: CGPoint(x: 80, y: 11), control2: CGPoint(x: 92, y: 22))
        path.addCurve(to: CGPoint(x: 50, y: 91), control1: CGPoint(x: 92, y: 63), control2: CGPoint(x: 52, y: 88))
        path.closeSubpath()
        return path
    }

    private var club: Path {
        var path = Path()
        path.move(to: CGPoint(x: 50, y: 8))
        path.addCurve(to: CGPoint(x: 25, y: 32), control1: CGPoint(x: 36, y: 8), control2: CGPoint(x: 25, y: 19))
        path.addCurve(to: CGPoint(x: 35, y: 50), control1: CGPoint(x: 25, y: 40), control2: CGPoint(x: 29, y: 46))
        path.addCurve(to: CGPoint(x: 13, y: 74), control1: CGPoint(x: 23, y: 52), control2: CGPoint(x: 13, y: 62))
        path.addCurve(to: CGPoint(x: 36, y: 95), control1: CGPoint(x: 13, y: 86), control2: CGPoint(x: 23, y: 95))
        path.addCurve(to: CGPoint(x: 48, y: 90), control1: CGPoint(x: 41, y: 95), control2: CGPoint(x: 45, y: 93))
        path.addCurve(to: CGPoint(x: 32, y: 106), control1: CGPoint(x: 47, y: 96), control2: CGPoint(x: 43, y: 102))
        path.addLine(to: CGPoint(x: 68, y: 106))
        path.addCurve(to: CGPoint(x: 52, y: 90), control1: CGPoint(x: 57, y: 102), control2: CGPoint(x: 53, y: 96))
        path.addCurve(to: CGPoint(x: 64, y: 95), control1: CGPoint(x: 55, y: 93), control2: CGPoint(x: 59, y: 95))
        path.addCurve(to: CGPoint(x: 87, y: 74), control1: CGPoint(x: 77, y: 95), control2: CGPoint(x: 87, y: 86))
        path.addCurve(to: CGPoint(x: 65, y: 50), control1: CGPoint(x: 87, y: 62), control2: CGPoint(x: 77, y: 52))
        path.addCurve(to: CGPoint(x: 75, y: 32), control1: CGPoint(x: 71, y: 46), control2: CGPoint(x: 75, y: 40))
        path.addCurve(to: CGPoint(x: 50, y: 8), control1: CGPoint(x: 75, y: 19), control2: CGPoint(x: 64, y: 8))
        path.closeSubpath()
        return path
    }

    private var diamond: Path {
        var path = Path()
        path.move(to: CGPoint(x: 50, y: 6))
        path.addCurve(to: CGPoint(x: 90, y: 50), control1: CGPoint(x: 52, y: 10), control2: CGPoint(x: 68, y: 34))
        path.addCurve(to: CGPoint(x: 50, y: 94), control1: CGPoint(x: 68, y: 66), control2: CGPoint(x: 52, y: 90))
        path.addCurve(to: CGPoint(x: 10, y: 50), control1: CGPoint(x: 48, y: 90), control2: CGPoint(x: 32, y: 66))
        path.addCurve(to: CGPoint(x: 50, y: 6), control1: CGPoint(x: 32, y: 34), control2: CGPoint(x: 48, y: 10))
        path.closeSubpath()
        return path
    }
}

/// Vertically centred empty-home cluster: the suit fan plus the existing primary CTA.
/// The CTA is tappable from t = 0 (motion-spec rule zero). Plays once on appear.
struct EmptyHomeCluster: View {
    let theme: Theme
    let ctaTitle: String
    let onStart: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dealt = false
    @State private var ctaPresented = false
    @State private var clusterAppeared = false

    var body: some View {
        VStack(spacing: 16) {
            EmptyHomeFan(theme: theme, atRest: cardsAtRest)
            PrimaryButton(title: ctaTitle, height: 60, fontSize: 19, action: onStart)
                .accessibilityIdentifier("home.newSession")
                .opacity(ctaAtRest ? 1 : 0)
                .offset(y: ctaAtRest ? 0 : 8)
                .animation(ctaAnimation, value: ctaAtRest)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .opacity(clusterOpacity)
        .accessibilityIdentifier("home.emptyState")
        .onAppear(perform: appear)
    }

    /// 動畫效果 off, or Reduce Motion: jump / fade to the rest pose, no deal-in.
    private var cardsAtRest: Bool {
        !MotionSettings.enabled || reduceMotion || dealt
    }

    private var ctaAtRest: Bool {
        !MotionSettings.enabled || reduceMotion || ctaPresented
    }

    private var clusterOpacity: Double {
        if !MotionSettings.enabled { return 1 }
        if reduceMotion { return clusterAppeared ? 1 : 0 }
        return 1
    }

    private var ctaAnimation: Animation? {
        guard MotionSettings.enabled, !reduceMotion else { return nil }
        return theme.easeOut(duration: 0.25)
    }

    private func appear() {
        if !MotionSettings.enabled {
            dealt = true
            ctaPresented = true
            clusterAppeared = true
            return
        }
        if reduceMotion {
            dealt = true
            ctaPresented = true
            withAnimation(.easeInOut(duration: 0.15)) {
                clusterAppeared = true
            }
            return
        }
        clusterAppeared = true
        // Commit the stacked / faded start frame first so the deal-in actually plays.
        // This does not gate input (rule zero): the CTA is hittable at opacity 0.
        Task { @MainActor in
            dealt = true
            ctaPresented = true
        }
    }
}
