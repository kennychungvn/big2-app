import SwiftUI
import StoreKit
import UIKit
import AppCore
import ScoringEngine

struct FinalView: View {
    @EnvironmentObject private var vm: AppViewModel
    @Environment(\.requestReview) private var requestReview
    @Environment(\.appTheme) private var theme
    let sessionID: UUID

    @State private var shareImage: Image?
    @State private var revealed = false
    @State private var crownVisible = false
    @State private var didStartReveal = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isEditing = false
    @State private var input = ""
    @State private var fieldWasFocused = false
    @FocusState private var isFieldFocused: Bool

    @AppStorage(ScoreConversion.enabledDefaultsKey) private var isEnabled = false
    @AppStorage(ScoreConversion.multiplierDefaultsKey) private var savedMultiplier = 0

    var body: some View {
        Group {
            if let stored = stored {
                content(stored)
            } else {
                Text(tr("搵唔到呢場。"))
                    .foregroundColor(Color(theme.secondaryText))
            }
        }
        .background(Color(theme.background).ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(tr("‹ 首頁")) { vm.goHome() }
                    .accessibilityIdentifier("nav.home")
                    .foregroundColor(Color(theme.accentLink))
            }
            ToolbarItem(placement: .principal) {
                Text(tr("完場"))
                    .accessibilityIdentifier("final.title")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Color(theme.text))
            }
        }
        .toolbarBackground(Color(theme.background), for: .navigationBar)
        .toolbarColorScheme(theme.colorScheme, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            restoreInput()
            renderShareImage()
            startRevealIfNeeded()
        }
        .onChange(of: appliedMultiplier) { _ in
            renderShareImage()
        }
        // The share image follows the active skin and light/dark palette.
        .onChange(of: theme) { _ in
            renderShareImage()
        }
        .task(id: sessionID) {
            await offerReviewIfNeeded()
        }
    }

    private var stored: StoredSession? {
        vm.model.data.sessions.first(where: { $0.id == sessionID })
    }

    /// Live multiplier while editing; otherwise the persisted one.
    private var appliedMultiplier: Int? {
        if isEditing {
            return ScoreConversion.appliedMultiplier(enabled: true, input: input)
        }
        return ScoreConversion.appliedMultiplier(enabled: isEnabled, multiplier: savedMultiplier)
    }

    @ViewBuilder
    private func content(_ stored: StoredSession) -> some View {
        let summary = ShareSummary(stored: stored, format: vm.format, conversionMultiplier: appliedMultiplier)
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(tr("最終排名"))
                            .font(ThemeFont.sectionLabel(theme))
                            .foregroundColor(Color(theme.secondaryText))
                        Spacer()
                        Text("\(summary.dateLine) · \(summary.roundsLine)")
                            .font(.system(size: 13))
                            .foregroundColor(Color(theme.secondaryText))
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 10)

                    conversionButton
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)

                    if isEditing {
                        conversionField
                            .padding(.horizontal, 16)
                            .padding(.bottom, 8)
                    }

                    ForEach(Array(stored.session.ranking.enumerated()), id: \.element.index) { position, player in
                        HStack(spacing: 10) {
                            Text("\(player.rank)")
                                .font(ThemeFont.numeric(theme, size: 15, weight: .semibold))
                                .foregroundColor(Color(theme.tertiaryText))
                                .frame(width: 20)
                            PlayerColorDot(index: player.index)
                            HStack(spacing: 4) {
                                if player.rank == 1 {
                                    Text("👑")
                                        .opacity(crownVisible ? 1 : 0)
                                }
                                Text(player.name)
                            }
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(Color(theme.text))
                            Spacer()
                            rankScore(player.total)
                        }
                        .padding(.horizontal, 14)
                        .frame(minHeight: 62)
                        .themedCard(theme)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 4)
                        // 完場 reveal (motion §6): rank order, 60 ms stagger; input never waits.
                        .opacity(revealed ? 1 : 0)
                        .offset(y: revealed || reduceMotion ? 0 : 12)
                        .animation(
                            MotionSettings.animation(.timingCurve(0.2, 0, 0, 1, duration: 0.26), reduceMotion: reduceMotion)?
                                .delay(reduceMotion ? 0 : Double(position) * 0.06),
                            value: revealed
                        )
                        // Explicit label (same pattern as the scoreboard): children:.combine
                        // dropped RollingScoreText's target-value label because the
                        // animated glyph is accessibilityHidden, so VoiceOver/XCUITest
                        // saw the name but not "+124". Always the settled total, never
                        // the in-flight count-up (input never waits on animation).
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(rankAccessibilityLabel(name: player.name, total: player.total))
                        .accessibilityIdentifier("final.rank.\(player.rank)")
                    }
                }
                .padding(.bottom, 16)
            }
            .scrollDismissesKeyboard(.interactively)

            shareControls(summary: summary)
            AdSafeGap()
        }
    }

    @ViewBuilder
    private func rankScore(_ total: Int) -> some View {
        // One stable RollingScoreText so 換算 (and turning it off) rolls in place
        // instead of swapping views. Display-only: the raw total is unchanged.
        let displayed = appliedMultiplier.map { ScoreConversion.multiply(total, by: $0) } ?? total
        // Count up from 0 on first appear only when 動畫效果 is on and Reduce Motion is off.
        let countFromZero = MotionSettings.enabled && !reduceMotion
        VStack(alignment: .trailing, spacing: 2) {
            RollingScoreText(
                value: displayed,
                size: 26,
                format: vm.format,
                appearFrom: countFromZero ? 0 : nil,
                motion: .conversion,
                appearMotion: .settlement
            )
            if let multiplier = appliedMultiplier {
                Text("\(vm.format.points(total)) ×\(multiplier)")
                    .font(ThemeFont.numeric(theme, size: 12, weight: .semibold))
                    .foregroundColor(Color(theme.tertiaryText))
            }
        }
    }


    /// Settled score only (plus the raw ×N line when 換算 is on). The rolling
    /// glyph is display-only and hidden from VoiceOver.
    private func rankAccessibilityLabel(name: String, total: Int) -> String {
        let displayed = appliedMultiplier.map { ScoreConversion.multiply(total, by: $0) } ?? total
        if let multiplier = appliedMultiplier {
            return "\(name) \(vm.format.points(displayed)) \(vm.format.points(total)) ×\(multiplier)"
        }
        return "\(name) \(vm.format.points(displayed))"
    }

    private var conversionButtonTitle: String {
        if let multiplier = appliedMultiplier {
            return tr("換算 ×%@", "\(multiplier)")
        }
        return tr("換算")
    }

    private var isConversionOn: Bool {
        appliedMultiplier != nil
    }

    private var conversionButton: some View {
        Button(action: toggleConversion) {
            HStack(spacing: 8) {
                ConversionGlyph()
                    .frame(width: 20, height: 20)
                Text(conversionButtonTitle)
                    .font(.system(size: 17, weight: isConversionOn ? .heavy : .bold))
            }
            .foregroundColor(isConversionOn ? Color(theme.primaryText) : Color(theme.text))
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(isConversionOn ? Color(theme.primary) : Color(theme.surface2))
            .clipShape(RoundedRectangle(cornerRadius: theme.buttonCornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: theme.buttonCornerRadius, style: .continuous)
                    .strokeBorder(Color(theme.line), lineWidth: isConversionOn ? 0 : CGFloat(theme.cardBorderWidth))
            )
            .animation(MotionSettings.animation(.easeOut(duration: 0.15), reduceMotion: reduceMotion), value: isConversionOn)
        }
        .buttonStyle(PressStyle(amount: 0.97))
        .accessibilityIdentifier("final.conversion")
        .accessibilityLabel(conversionButtonTitle)
    }

    private var conversionField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(tr("倍數"))
                .font(ThemeFont.sectionLabel(theme))
                .foregroundColor(Color(theme.secondaryText))
                .padding(.horizontal, 4)
            TextField("", text: $input)
                .keyboardType(.numberPad)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .font(ThemeFont.numeric(theme, size: 26, weight: .bold))
                .foregroundColor(Color(theme.text))
                .padding(.horizontal, 16)
                .frame(height: 46)
                .background(Color(theme.background))
                .clipShape(RoundedRectangle(cornerRadius: theme.keyCornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: theme.keyCornerRadius, style: .continuous)
                        .strokeBorder(Color(theme.hi), lineWidth: 1.5)
                )
                .tint(Color(theme.hi))
                .focused($isFieldFocused)
                .onChange(of: input) { newValue in
                    inputDidChange(newValue)
                }
                .accessibilityIdentifier("final.conversion.field")
                .accessibilityLabel(tr("倍數"))
            Text(tr("下次會記住呢個倍數"))
                .font(.system(size: 12))
                .foregroundColor(Color(theme.secondaryText))
                .frame(maxWidth: .infinity)
                .padding(.top, 2)
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .themedCard(theme)
        .onAppear {
            fieldWasFocused = false
            DispatchQueue.main.async {
                isFieldFocused = true
            }
        }
        .onChange(of: isFieldFocused) { focused in
            if focused {
                fieldWasFocused = true
            } else if fieldWasFocused && isEditing {
                collapseField()
            }
        }
    }

    /// v1.1: one big yellow 分享結果圖 plus a small square Aa for the plain-text result.
    /// While the image is still rendering, the big button shares the text instead.
    @ViewBuilder
    private func shareControls(summary: ShareSummary) -> some View {
        HStack(spacing: 10) {
            Group {
                if let shareImage {
                    ShareLink(
                        item: shareImage,
                        preview: SharePreview(summary.title, image: shareImage)
                    ) {
                        shareLabel(tr("分享結果圖"))
                    }
                } else {
                    ShareLink(item: summary.text) {
                        shareLabel(tr("分享結果圖"))
                    }
                }
            }
            .accessibilityIdentifier("final.shareImage")

            ShareLink(item: summary.text) {
                Text("Aa")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color(theme.text))
                    .frame(width: 56, height: 56)
                    .themedCard(theme, radius: theme.buttonCornerRadius, fill: theme.surface2)
            }
            .accessibilityLabel(tr("分享文字結果"))
            .accessibilityIdentifier("final.shareText")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func shareLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 18, weight: theme.monoNumbers ? .semibold : .bold))
            .foregroundColor(Color(theme.primaryText))
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color(theme.primary))
            .clipShape(RoundedRectangle(cornerRadius: theme.buttonCornerRadius, style: .continuous))
    }

    /// Rows, score count-up and 👑 are display-only. 換算 and share stay tappable from frame 0.
    private func startRevealIfNeeded() {
        guard !didStartReveal else {
            revealed = true
            crownVisible = true
            return
        }
        didStartReveal = true
        revealed = true
        guard MotionSettings.enabled else {
            crownVisible = true
            return
        }
        if reduceMotion {
            // 150 ms list fade (already on the rows); final numbers, no slide, crown with the fade.
            withAnimation(.easeInOut(duration: 0.15)) {
                crownVisible = true
            }
            if vm.model.data.hapticsEnabled {
                ChaoHaptics.light()
            }
            return
        }
        // 👑 fades in last (150 ms) after the row reveal (~440 ms).
        withAnimation(.easeOut(duration: 0.15).delay(0.44)) {
            crownVisible = true
        }
        if vm.model.data.hapticsEnabled {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 260_000_000)
                ChaoHaptics.light()
            }
        }
    }

    private func restoreInput() {
        if savedMultiplier >= 1 && input.isEmpty {
            input = String(savedMultiplier)
        }
        if ScoreConversion.appliedMultiplier(enabled: isEnabled, multiplier: savedMultiplier) == nil {
            isEnabled = false
        }
        isEditing = false
    }

    private func inputDidChange(_ newValue: String) {
        let sanitized = ScoreConversion.sanitize(newValue)
        if sanitized != newValue {
            input = sanitized
        }
        if let value = ScoreConversion.parse(sanitized), value >= 1 {
            savedMultiplier = value
            isEnabled = value >= 2
        } else {
            isEnabled = false
        }
    }

    private func toggleConversion() {
        if isEditing {
            isFieldFocused = false
            collapseField()
            return
        }
        if ScoreConversion.appliedMultiplier(enabled: isEnabled, multiplier: savedMultiplier) != nil {
            isEnabled = false
            return
        }
        if savedMultiplier >= 1 {
            input = String(savedMultiplier)
        } else {
            input = ""
        }
        isEditing = true
        isEnabled = savedMultiplier >= 2
    }

    private func collapseField() {
        isEditing = false
        if ScoreConversion.appliedMultiplier(enabled: true, input: input) != nil {
            isEnabled = true
        } else {
            isEnabled = false
        }
    }

    private func renderShareImage() {
        guard let stored else { return }
        let summary = ShareSummary(stored: stored, format: vm.format, conversionMultiplier: appliedMultiplier)
        let renderer = ImageRenderer(content: ShareCardView(summary: summary, theme: theme))
        renderer.scale = UIScreen.main.scale
        if let uiImage = renderer.uiImage {
            shareImage = Image(uiImage: uiImage)
        }
    }

    /// Native App Store review prompt after the 3rd 完場, once the settlement screen is up.
    /// Skipped when opening a past game from history, during UI tests, or if an interstitial is still up.
    private func offerReviewIfNeeded() async {
        guard vm.consumePendingReviewPrompt(for: sessionID) else { return }
        try? await Task.sleep(nanoseconds: ReviewPromptPolicy.settlementDelayNanoseconds)
        guard !Task.isCancelled else { return }
        guard vm.isReviewPromptEligible() else { return }
        requestReview()
        vm.markReviewPromptShown()
    }
}

/// Rounded square with an X, matching the approved 換算 mockup glyph.
private struct ConversionGlyph: View {
    var body: some View {
        ConversionGlyphShape()
            .stroke(style: StrokeStyle(lineWidth: 1.7, lineCap: .round, lineJoin: .round))
    }
}

private struct ConversionGlyphShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let box = rect.insetBy(dx: 1.05, dy: 1.05)
        path.addRoundedRect(in: box, cornerSize: CGSize(width: rect.width * 0.22, height: rect.height * 0.22))
        let scaleX = rect.width / 20
        let scaleY = rect.height / 20
        path.move(to: CGPoint(x: 7 * scaleX, y: 7 * scaleY))
        path.addLine(to: CGPoint(x: 13 * scaleX, y: 13 * scaleY))
        path.move(to: CGPoint(x: 13 * scaleX, y: 7 * scaleY))
        path.addLine(to: CGPoint(x: 7 * scaleX, y: 13 * scaleY))
        return path
    }
}
