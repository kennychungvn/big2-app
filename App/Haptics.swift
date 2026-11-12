import UIKit

enum ChaoHaptics {
    /// Light / medium / heavy impact with intensity scaled by 炒倍.
    static func play(multiplier: Int) {
        let style: UIImpactFeedbackGenerator.FeedbackStyle
        let intensity: CGFloat
        switch multiplier {
        case 4...:
            style = .heavy
            intensity = 1.0
        case 3:
            style = .medium
            intensity = 0.75
        default:
            style = .light
            intensity = 0.5
        }
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred(intensity: intensity)
    }
}
