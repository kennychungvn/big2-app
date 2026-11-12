import SwiftUI
import UIKit

/// Keeps the screen awake while a scoring session is on screen.
struct KeepAwakeModifier: ViewModifier {
    let active: Bool

    func body(content: Content) -> some View {
        content
            .onAppear { Self.setIdleTimerDisabled(active) }
            .onChange(of: active) { newValue in
                Self.setIdleTimerDisabled(newValue)
            }
            .onDisappear { Self.setIdleTimerDisabled(false) }
    }

    private static func setIdleTimerDisabled(_ disabled: Bool) {
        UIApplication.shared.isIdleTimerDisabled = disabled
    }
}

extension View {
    func keepAwake(_ active: Bool = true) -> some View {
        modifier(KeepAwakeModifier(active: active))
    }
}
