import SwiftUI
import AppCore
import ScoringEngine

struct SettingsView: View {
    static let privacyPolicyURL = URL(string: "https://kennychungvn.github.io/daidee-site/privacy.html")!

    @EnvironmentObject private var vm: AppViewModel
    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var adsRuntime = AdsRuntime.shared
    @State private var showingStoreLog = false

    var body: some View {
        NavigationStack {
            List {
                if L10n.taiwanEnabled && !AppFlavor.current.isTaiwanApp {
                Section {
                    Picker(tr("地區介面"), selection: regionBinding) {
                        ForEach(InterfaceRegionPreference.allCases, id: \.self) { preference in
                            Text(preference.title(in: vm.region)).tag(preference)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("settings.region")
                } header: {
                    Text(tr("地區介面"))
                } footer: {
                    Text(tr("揀「台灣」會用大老二用語，第一次開場預設台灣常見炒法（10-12張 ×2 · 13張 ×3）。"))
                }
                .listRowBackground(Color(theme.card))
                }

                if AppFlavor.current.isTaiwanApp {
                    Section {
                        Picker(tr("計分方式"), selection: scoringModeBinding) {
                            Text(tr("贏家通吃")).tag(ScoringMode.winnerTakesAll)
                            Text(tr("互對")).tag(ScoringMode.pairwise)
                        }
                        .pickerStyle(.segmented)
                        .accessibilityIdentifier("settings.scoringMode")
                        Text(vm.model.data.lastSettings.scoringMode == .pairwise
                             ? tr("互對：每兩位玩家依計算後分數的差額互相結算。")
                             : tr("贏家通吃：其餘玩家依剩餘張數與門檻計算，全數給贏家。"))
                            .font(.system(size: 13))
                            .foregroundColor(Color(theme.secondaryText))
                    } header: {
                        sectionHeader(tr("計分方式"))
                    } footer: {
                        Text(tr("下次開新牌局時套用，不會改到進行中的牌局。"))
                    }
                    .listRowBackground(Color(theme.card))

                    Section {
                        Text(tr("1–7 張固定 ×1。預設 8 張起 ×2、10 張起 ×3、13 張 ×4，點格可調整。"))
                            .font(.system(size: 13))
                            .foregroundColor(Color(theme.secondaryText))
                        HStack(spacing: 6) {
                            ForEach(Array(ChaoTable.editableCounts), id: \.self) { cards in
                                settingsTile(cards: cards)
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                    } header: {
                        sectionHeader(tr("加倍門檻"))
                    }
                    .listRowBackground(Color(theme.card))
                }

                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(tr("一次過買斷，之後唔再見到廣告。"))
                            .font(.system(size: 14))
                            .foregroundColor(Color(theme.secondaryText))
                        if vm.model.data.adsRemoved {
                            Label(tr("已經移除廣告"), systemImage: "checkmark.seal.fill")
                                // One element reading the text (the id alone landed on the icon).
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel(tr("已經移除廣告"))
                                .accessibilityIdentifier("settings.adsRemoved")
                                .foregroundColor(Color(theme.positive))
                                .font(.system(size: 16, weight: .semibold))
                        } else {
                            Button {
                                Task { await vm.purchaseRemoveAds() }
                            } label: {
                                HStack {
                                    Text(tr("移除廣告"))
                                        .font(.system(size: 17, weight: .semibold))
                                    Spacer()
                                    if vm.isStoreBusy {
                                        ProgressView()
                                            .tint(Color(theme.primaryText))
                                    } else {
                                        Text(vm.shop.removeAdsPriceLabel)
                                            .font(.system(size: 17, weight: .bold))
                                    }
                                }
                                .foregroundColor(Color(theme.primaryText))
                                .padding(.vertical, 10)
                                .padding(.horizontal, 14)
                                .background(Color(theme.primary))
                                .clipShape(RoundedRectangle(cornerRadius: theme.buttonCornerRadius - 4, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .disabled(vm.isStoreBusy)
                            .accessibilityIdentifier("settings.removeAds")
                        }
                    }
                    .padding(.vertical, 6)

                    Button(tr("回復購買")) {
                        Task { await vm.restorePurchases() }
                    }
                    .foregroundColor(Color(theme.accentLink))
                    .disabled(vm.isStoreBusy)
                    .accessibilityIdentifier("settings.restorePurchases")

                    // Required by Google UMP where consent applies (EEA / UK / some US states).
                    if adsRuntime.privacyOptionsRequired {
                        Button(tr("廣告私隱設定")) {
                            Task { await AdsRuntime.shared.presentPrivacyOptions() }
                        }
                        .foregroundColor(Color(theme.accentLink))
                    }

                } header: {
                    sectionHeader(tr("購買"))
                } footer: {
                    Text(tr("%@ 係一次性購買（非訂閱），買咗之後所有廣告永久移除；換機或重裝可用「回復購買」。", tr(StoreProduct.removeAdsDisplayName)))
                }
                .listRowBackground(Color(theme.card))

                skinSection

                Section {
                    Toggle(isOn: animationBinding) {
                        Text(tr("動畫效果"))
                    }
                    .accessibilityIdentifier("settings.motion")
                    Toggle(isOn: hapticsBinding) {
                        Text(tr("震機提示"))
                    }
                    NavigationLink {
                        KnownNamesSettingsView()
                    } label: {
                        Text(tr("管理快速填入名稱"))
                    }
                    .accessibilityIdentifier("settings.knownNames")
                } header: {
                    sectionHeader(tr("體驗"))
                }
                .listRowBackground(Color(theme.card))

                Section {
                    HStack {
                        Text(tr("版本"))
                        Spacer()
                        Text(versionString)
                            .foregroundColor(Color(theme.secondaryText))
                    }
                    .contentShape(Rectangle())
                    // Hidden 購買紀錄 (debug): StoreKit events for troubleshooting 移除廣告.
                    .onLongPressGesture(minimumDuration: 0.8) {
                        showingStoreLog = true
                    }
                    .accessibilityIdentifier("settings.version")

                    if let reviewURL = ReviewPromptPolicy.writeReviewURL {
                        Link(destination: reviewURL) {
                            Text(tr("為 App 評分"))
                        }
                        .foregroundColor(Color(theme.accentLink))
                        .accessibilityIdentifier("settings.writeReview")
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text(tr("免責聲明"))
                            .font(.system(size: 14, weight: .semibold))
                        Text(LegalCopy.disclaimer)
                            .font(.system(size: 13))
                            .foregroundColor(Color(theme.secondaryText))
                    }
                    .padding(.vertical, 4)

                    Text(tr("玩家名同分數只係儲喺你部手機，唔會上傳到我哋嘅伺服器。廣告同當機報告由 Google 處理，詳情請睇私隱政策。"))
                        .font(.system(size: 13))
                        .foregroundColor(Color(theme.secondaryText))

                    Link(destination: Self.privacyPolicyURL) {
                        Text(tr("私隱政策"))
                    }
                    .foregroundColor(Color(theme.accentLink))
                    .accessibilityIdentifier("settings.privacyPolicy")
                } header: {
                    sectionHeader(tr("關於"))
                }
                .listRowBackground(Color(theme.card))
            }
            .scrollContentBackground(.hidden)
            .background(Color(theme.background).ignoresSafeArea())
            .tint(Color(theme.toggle))
            .navigationDestination(isPresented: $showingStoreLog) {
                StoreDebugLogView()
            }
            .navigationTitle(tr("設定"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(tr("完成")) { dismiss() }
                        .accessibilityIdentifier("settings.done")
                        .foregroundColor(Color(theme.accentLink))
                }
            }
            .toolbarBackground(Color(theme.background), for: .navigationBar)
            .toolbarColorScheme(theme.colorScheme, for: .navigationBar)
        }
        .preferredColorScheme(theme.colorScheme)
        .alert(item: $vm.storeAlert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text(tr("知道")))
            )
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(ThemeFont.sectionLabel(theme))
            .foregroundColor(Color(theme.secondaryText))
    }

    // MARK: 主題及外觀 (2.0)

    /// Two fixed looks: 經典 (dark) and Ledger (light). Tapping a tile
    /// switches the theme and the matching app icon together.
    private var skinSection: some View {
        Section {
            HStack(spacing: 10) {
                ForEach(SkinID.allCases) { skin in
                    skinTile(skin)
                }
            }
            .padding(.vertical, 4)
        } header: {
            sectionHeader(tr("主題及外觀"))
        }
        .listRowBackground(Color(theme.card))
    }

    private func skinTile(_ skin: SkinID) -> some View {
        let selected = vm.skin == skin
        return Button {
            vm.setSkin(skin)
        } label: {
            HStack(spacing: 8) {
                Image(skin.iconPreviewName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                Text(skin.displayName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color(theme.text))
                Spacer(minLength: 0)
            }
            .padding(8)
            .frame(maxWidth: .infinity)
            .themedCard(theme, radius: theme.keyCornerRadius, fill: theme.surface2, selected: selected)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("settings.skin.\(skin.rawValue)")
        .accessibilityLabel(skin.displayName)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var animationBinding: Binding<Bool> {
        Binding(
            get: { vm.model.data.chaoAnimationEnabled },
            set: { vm.setChaoAnimationEnabled($0) }
        )
    }

    private var regionBinding: Binding<InterfaceRegionPreference> {
        Binding(
            get: { vm.model.data.regionPreference },
            set: { vm.setRegionPreference($0) }
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

    private var scoringModeBinding: Binding<ScoringMode> {
        Binding(
            get: { vm.model.data.lastSettings.scoringMode ?? AppFlavor.current.defaultScoringMode },
            set: { vm.setDefaultScoringMode($0) }
        )
    }

    private var settingsChaoTable: ChaoTable {
        vm.model.data.lastSettings.chaoTable ?? AppFlavor.current.defaultChaoTable
    }

    private func settingsTile(cards: Int) -> some View {
        let multiplier = settingsChaoTable.multiplier(forCards: cards)
        let foreground = Color(theme.keyTextColor(forMultiplier: multiplier))
        return Button {
            var table = settingsChaoTable
            table.cycle(cards: cards)
            vm.setDefaultChaoTable(table)
            if vm.model.data.hapticsEnabled {
                ChaoHaptics.play(multiplier: table.multiplier(forCards: cards))
            }
        } label: {
            VStack(spacing: 2) {
                Text(tr("%@張", "\(cards)"))
                    .font(.system(size: 12, weight: .medium))
                    .opacity(0.85)
                Text("×\(multiplier)")
                    .font(.system(size: 18, weight: .heavy))
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
            }
            .foregroundColor(foreground)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Color(theme.keyColor(forMultiplier: multiplier)))
            .clipShape(RoundedRectangle(cornerRadius: theme.keyCornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("settings.tile.\(cards)")
        .accessibilityValue("×\(multiplier)")
    }
}

