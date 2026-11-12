import SwiftUI
import UIKit
import AppCore
import ScoringEngine

struct FinalView: View {
    @EnvironmentObject private var vm: AppViewModel
    @Environment(\.appTheme) private var theme
    let sessionID: UUID

    @State private var shareImage: Image?

    var body: some View {
        Group {
            if let stored = stored {
                content(stored)
            } else {
                Text("搵唔到呢場。")
                    .foregroundColor(Color(theme.secondaryText))
            }
        }
        .background(Color(theme.background).ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("‹ 首頁") { vm.goHome() }
                    .foregroundColor(Color(theme.accentLink))
            }
            ToolbarItem(placement: .principal) {
                Text("完場")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color(theme.text))
            }
        }
        .toolbarBackground(Color(theme.background), for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { renderShareImage() }
    }

    private var stored: StoredSession? {
        vm.model.data.sessions.first(where: { $0.id == sessionID })
    }

    @ViewBuilder
    private func content(_ stored: StoredSession) -> some View {
        let summary = ShareSummary(stored: stored, format: vm.format)
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("最終排名")
                        .font(.system(size: 13))
                        .foregroundColor(Color(theme.secondaryText))
                        .padding(.horizontal, 18)
                        .padding(.top, 8)
                        .padding(.bottom, 6)

                    Text("\(summary.dateLine) · \(summary.roundsLine)")
                        .font(.system(size: 15))
                        .foregroundColor(Color(theme.secondaryText))
                        .padding(.horizontal, 18)
                        .padding(.bottom, 8)

                    ForEach(Array(stored.session.ranking.enumerated()), id: \.element.index) { _, player in
                        HStack(spacing: 10) {
                            Text("\(player.rank)")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(Color(theme.secondaryText))
                                .frame(width: 24)
                            PlayerColorDot(index: player.index, height: 32)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(player.rank == 1 ? "👑 \(player.name)" : player.name)
                                    .font(.system(size: 19, weight: .semibold))
                                    .foregroundColor(Color(theme.text))
                                MoneyText(value: player.money, format: vm.format)
                            }
                            Spacer()
                            ScoreText(value: player.total, size: 28, format: vm.format)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(Color(theme.card))
                        .clipShape(RoundedRectangle(cornerRadius: theme.cardCornerRadius, style: .continuous))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 5)
                    }

                    if stored.session.pointValue != nil {
                        Text("每分 $\(NSDecimalNumber(decimal: stored.session.pointValue ?? 0).stringValue)")
                            .font(.system(size: 13))
                            .foregroundColor(Color(theme.secondaryText))
                            .padding(.horizontal, 18)
                            .padding(.top, 10)
                    }
                }
                .padding(.bottom, 16)
            }

            shareControls(summary: summary)
            AdSafeGap()
        }
    }

    @ViewBuilder
    private func shareControls(summary: ShareSummary) -> some View {
        VStack(spacing: 10) {
            if let shareImage {
                ShareLink(
                    item: shareImage,
                    preview: SharePreview(summary.title, image: shareImage)
                ) {
                    shareLabel("分享結果圖")
                }
                .padding(.horizontal, 18)
            }
            ShareLink(item: summary.text) {
                Text("分享文字結果")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(theme.text))
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color(theme.card))
                    .clipShape(RoundedRectangle(cornerRadius: theme.buttonCornerRadius, style: .continuous))
            }
            .padding(.horizontal, 18)
        }
        .padding(.vertical, 10)
    }

    private func shareLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 20, weight: .heavy))
            .foregroundColor(Color(theme.primaryText))
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color(theme.primary))
            .clipShape(RoundedRectangle(cornerRadius: theme.buttonCornerRadius, style: .continuous))
    }

    private func renderShareImage() {
        guard let stored else { return }
        let summary = ShareSummary(stored: stored, format: vm.format)
        let renderer = ImageRenderer(content: ShareCardView(summary: summary, theme: theme))
        renderer.scale = UIScreen.main.scale
        if let uiImage = renderer.uiImage {
            shareImage = Image(uiImage: uiImage)
        }
    }
}
