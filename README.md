# 鋤大D計分（iOS 16+）

打牌計分 app 嘅 SwiftUI 畫面層，用「街坊」皮（深灰底、黃色主掣），接住現成嘅 `ScoringEngine`。

**免責聲明：** 呢個 app 淨係用嚟記分，唔涉及任何賭博或金錢交易。

冇 Mac 都可以繼續：用 GitHub Actions 喺雲端 compile，再用 TestFlight 裝落 iPhone。詳細步驟（用 iPhone 瀏覽器都做得）見 [`docs/SETUP_GITHUB_TESTFLIGHT.md`](docs/SETUP_GITHUB_TESTFLIGHT.md)。私隱政策同使用條款草稿見 [`docs/privacy-policy.md`](docs/privacy-policy.md) 同 [`docs/terms.md`](docs/terms.md)。

呢個 folder 已經齊晒畫面、本機存檔、入牌邏輯、廣告同內購嘅預留位，同埋雲端 build 設定。Apple Developer 用個人名義開（US$99）。帳戶未開好之前，每一次將 code 推上 GitHub 都會自動跑模擬器 compile 同測試，唔使 Apple 帳戶。

## 檔案點排

```
big2-app/
├── Package.swift              AppCore 套件（Linux 都可以 compile / test）
├── project.yml                XcodeGen 設定，喺 Mac 產生 Xcode project
├── README.md
├── docs/                      GitHub / TestFlight 教學、私隱政策、使用條款
├── .github/workflows/ios.yml  雲端 build 同 TestFlight 上傳
├── Packages/ScoringEngine/    計分引擎（已經包喺入面，唔使另外搵）
├── Sources/AppCore/           唔依賴 SwiftUI 嘅邏輯：存檔、入牌 state machine、主題色、格式
├── Tests/AppCoreTests/        上述邏輯嘅單元測試
└── App/                       iOS SwiftUI 畫面（要 Xcode 先 compile 到）
    ├── Big2App.swift          App 入口
    ├── AppViewModel.swift     畫面之間嘅狀態、存檔、廣告／內購呼叫
    ├── Info.plist
    ├── Assets.xcassets        App icon、主題黃
    ├── Theme/                 將 Theme 轉成 SwiftUI Color / Font
    ├── Views/                 各個畫面
    ├── Ads/                   Banner 佔位 + 註解咗嘅 AdMob 接法
    └── Store/                 StoreKit 2 移除廣告 + 本機測試用 .storekit
```

畫面同核准咗嘅 wireframe 對齊：

1. **HomeView** — 「新開一場」、有未完場就顯示「繼續上一場」、最近場次列表
2. **NewSessionView** — 四個名、常用名 chips、計分規則（香港：香港炒／唔炒／經典；台灣：台灣常見／香港算法／不加倍），記住上次設定。只計分，冇金錢功能
3. **ScoreboardView** — 2×2 累計分（領先者有皇冠）、每局紀錄（㩒一行可編輯）、「入今局」大掣、廣告安全距離
4. **RoundEntryView** — 「贏」掣、1–13 數字鍵盤（顏色跟炒倍）、撤回／清除；最後一個入完自動計分；炒 ×2／×3／×4 喺同一行彈徽章（spring），再加震機
5. **RoundResultView** — 每個人今局加減同炒詳情，3 秒自動收，5 秒內可以撤回
6. **FinalView** — 完場排名同分數，可用 ShareLink 分享結果圖同文字

進行中嘅場會保持屏幕常亮（`isIdleTimerDisabled`）。資料用 JSON 檔存喺本機，冇用 SwiftData，所以 iOS 16 都用得。

## 冇 Mac：GitHub Actions + TestFlight（建議路徑）

詳細逐步教學見 [`docs/SETUP_GITHUB_TESTFLIGHT.md`](docs/SETUP_GITHUB_TESTFLIGHT.md)。簡單講：

1. 用 `kennychungvn` 開一個 **private** 空 repo（唔好加 README）。
2. 用 GitHub device code 授權我幫你 push，或者喺電腦網頁自己上傳檔案。
3. 開好 Apple Developer（個人名義）之後，喺 App Store Connect 開 app 記錄同 API key（角色揀 App Manager），再將 `ASC_KEY_ID`、`ASC_ISSUER_ID`、`ASC_KEY_P8`、`APPLE_TEAM_ID` 加去 repo 嘅 Actions secrets。
4. 喺 Actions 撳 **Run workflow**。Job A 會喺雲端 Mac compile 同跑測試；Job B 會打包上傳 TestFlight（secrets 未齊會自動跳過，唔會當失敗）。Build number 會用 GitHub `run_number` 自動加。
5. 用 TestFlight app 裝落 iPhone。你自己做 Internal Tester 唔使過 beta review。

Bundle ID 暫時係 `com.kenny.daidee`。

## 喺 Mac 用 XcodeGen 開 project（如果之後有 Mac）

1. 安裝 [Xcode](https://developer.apple.com/xcode/)（App Store）同 [Homebrew](https://brew.sh/)，然後：

   ```bash
   brew install xcodegen
   ```

2. 將呢個 `big2-app` folder 拷去 Mac，喺 Terminal：

   ```bash
   cd big2-app
   xcodegen generate
   open Big2.xcodeproj
   ```

3. 喺 Xcode 選中 **Big2** target → Signing & Capabilities，Team 揀你嘅 Apple ID（免費都得）。Bundle ID 而家係 `com.kenny.daidee`，如果俾人用咗就改一個屬於你嘅。

4. 用線連 iPhone，解鎖、信任呢部電腦，喺 Xcode 頂部揀你部機，㩒 Run。第一次會要喺 iPhone「設定 → 一般 → VPN 與裝置管理」信任你個開發者證書。

XcodeGen 已經將 `App/Store/Products.storekit` 綁咗去 Run scheme。喺模擬器或者連住 Xcode 跑，可以本機試 HK$8「移除廣告」，唔使真係俾錢。商品 id 係 `com.kenny.daidee.removeads`，正式上架前要喺 App Store Connect 建同一個 id 嘅非消耗性商品。

## 唔用 XcodeGen、自己喺 Xcode 開

1. Xcode → File → New → Project → iOS App。Interface 揀 SwiftUI，語言 Swift，最低 iOS 16。唔好勾 SwiftData。Product Name 可以叫 `Big2`。
2. 刪走 Xcode 自動產生嘅 `ContentView.swift`、`Big2App.swift`（如果有）。
3. 將呢個 repo 嘅 `App/` 裏面所有 Swift 檔、`Assets.xcassets`、`Info.plist` 拖入 project（勾 Copy items if needed）。
4. 加本地套件：File → Add Package Dependencies → **Add Local…**
   - 先加 `big2-app` 呢個資料夾本身（product 揀 **AppCore**）
   - AppCore 會自動拎埋入面嘅 `Packages/ScoringEngine`，通常唔使再加一次
5. Target → General → Frameworks 確認有 `AppCore`。Deployment Target 設 iOS 16.0。iPhone only。
6. Target → Info / Build Settings，將 Info.plist 指去 `App/Info.plist`，或者用而家呢份取代自動產生嗰份。
7. Signing 同上面一樣揀 Team，接 iPhone 跑。
8. （可選）Edit Scheme → Run → Options → StoreKit Configuration，揀 `App/Store/Products.storekit`。

## 喺 Linux 驗證邏輯（已經跑過）

畫面一定要 Mac / Xcode 先 compile 到，但計分、入牌流程、存檔、廣告節奏全部抽咗去 `AppCore`，Linux 都可以測：

```bash
cd big2-app
swift test
```

`Packages/ScoringEngine` 本身都可以再跑一次：

```bash
cd Packages/ScoringEngine
swift test
```

## 廣告同內購（預留咗位，而家未接真服務）

- **Banner**：每個主畫面底部有 320×50 佔位，廣告同掣之間有安全距離，減少誤觸。買咗「移除廣告」就唔顯示。
- **插頁廣告**：每完成 5 局，下一次㩒「入今局」先考慮播（唔會喺剛計完分嗰下彈出）。兩次之間最少隔 180 秒。廣告未 load 好就直接入去入牌，唔會等人。真正嘅 AdMob 寫法註解喺 `App/Ads/AdMobStub.swift`，到時加 Google Mobile Ads package 再打開就得。
- **內購**：一次性 HK$8 永久無廣告，唔做訂閱。`StoreKitStoreManager` 用 StoreKit 2，有「移除廣告」同「恢復購買」。設定入面仲有炒動畫／震機開關。

上架前要喺 App Store Connect 放私隱政策同使用條款嘅公開連結（Apple 審 IAP 會睇）。草稿已經寫咗喺 `docs/privacy-policy.md` 同 `docs/terms.md`，聯絡電郵仲係暫定 `[YOUR-EMAIL@example.com]`，公開前要換。設定頁「關於」已經有免責聲明。

## 之後先做嘅 side quest

- 「至尊」「冠軍」兩款皮：`Theme` 已經抽走，而家淨係做咗「街坊」，加皮唔使改畫面 code
- Emoji avatar、燶咗效果、Lottie 火花：入牌徽章而家係簡單嘅 spring 動畫，之後可以換
- AdMob 真實 unit id、App Store Connect 商品、Developer Program 年費

有問題喺 Xcode 第一次 build 嘅話，最常見係 Signing Team 未揀，或者 iPhone 未信任開發者證書。

## 香港／台灣介面

- 同一隻 app，兩套文字：`App/zh-Hant-HK.lproj`（廣東話：鋤大D、計分、炒、入今局）同 `App/zh-Hant-TW.lproj`（台灣華語：大老二、記分、加倍、記這一局）。
- 文字表喺 `scripts/l10n_table.py`，改完跑 `python3 scripts/gen_l10n.py` 重新生成 `.strings`（會檢查有冇漏 key 同台灣版有冇廣東話字）。
- 設定 →「地區介面」：跟系統（預設）／香港／台灣。跟系統規則：電話語言係 zh-Hant-TW 或者地區係台灣 → 台灣；語言明確係香港／澳門中文 → 香港；其他 → 香港。
- 台灣介面新開一場預設「台灣常見」：1-9張 ×1 · 10-12張 ×2 · 13張 ×3。
- 主畫面 app 名跟 iOS 語言：香港「鋤大D計分」、台灣「大老二記分」（`InfoPlist.strings`）。
