import SwiftUI
import AppCore

struct SettingsView: View {
    @EnvironmentObject private var vm: AppViewModel
    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("一次過買斷，之後唔再見到廣告。")
                            .font(.system(size: 14))
                            .foregroundColor(Color(theme.secondaryText))
                        if vm.model.data.adsRemoved {
                            Label("已經移除廣告", systemImage: "checkmark.seal.fill")
                                .foregroundColor(Color(theme.positive))
                                .font(.system(size: 16, weight: .semibold))
                        } else {
                            Button {
                                Task { await vm.purchaseRemoveAds() }
                            } label: {
                                HStack {
                                    Text("移除廣告")
                                        .font(.system(size: 17, weight: .semibold))
                                    Spacer()
                                    Text(StoreProduct.removeAdsDisplayPrice)
                                        .font(.system(size: 17, weight: .bold))
                                }
                                .foregroundColor(Color(theme.primaryText))
                                .padding(.vertical, 10)
                                .padding(.horizontal, 14)
                                .background(Color(theme.primary))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .disabled(vm.shop.isPurchasing)
                        }
                    }
                    .padding(.vertical, 6)

                    Button("恢復購買") {
                        Task { await vm.restorePurchases() }
                    }
                    .foregroundColor(Color(theme.accentLink))

                    if let message = vm.storeMessage {
                        Text(message)
                            .font(.system(size: 13))
                            .foregroundColor(Color(theme.secondaryText))
                    }
                } header: {
                    Text("購買")
                } footer: {
                    Text("\(StoreProduct.removeAdsDisplayName) 係一次性購買（非訂閱），商品編號暫時係 \(StoreProduct.removeAdsProductID)，上架前會喺 App Store Connect 設定。")
                }

                Section("體驗") {
                    Toggle(isOn: animationBinding) {
                        Text("炒倍動畫")
                    }
                    Toggle(isOn: hapticsBinding) {
                        Text("震機提示")
                    }
                }

                Section("關於") {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text(versionString)
                            .foregroundColor(Color(theme.secondaryText))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("免責聲明")
                            .font(.system(size: 14, weight: .semibold))
                        Text(LegalCopy.disclaimer)
                            .font(.system(size: 13))
                            .foregroundColor(Color(theme.secondaryText))
                    }
                    .padding(.vertical, 4)

                    Text("玩家名同分數只係儲喺你部手機，唔會上傳到我哋嘅伺服器。私隱政策同使用條款會喺上架前補上公開連結。")
                        .font(.system(size: 13))
                        .foregroundColor(Color(theme.secondaryText))
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color(theme.background).ignoresSafeArea())
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                        .foregroundColor(Color(theme.accentLink))
                }
            }
            .toolbarBackground(Color(theme.background), for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
    }

    private var animationBinding: Binding<Bool> {
        Binding(
            get: { vm.model.data.chaoAnimationEnabled },
            set: { vm.setChaoAnimationEnabled($0) }
        )
    }

    private var hapticsBinding: Binding<Bool> {
        Binding(
            get: { vm.model.data.hapticsEnabled },
            set: { vm.setHapticsEnabled($0) }
        )
    }

    private var versionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
