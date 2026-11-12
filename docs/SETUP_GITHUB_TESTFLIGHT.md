# 用 GitHub Actions + TestFlight 裝 app（唔使 Mac）

你已經開咗 GitHub 帳戶 **kennychungvn**。跟住用**個人名義**開 Apple Developer（US$99）。呢份教學盡量用 iPhone 瀏覽器或者 GitHub / App Store Connect 網頁就可以做完。

我已經喺專案入面準備好自動 build 設定（`.github/workflows/ios.yml`）。**我而家唔會自己將 code 推上 GitHub，亦唔會用你嘅帳戶登入任何地方。** 等你開好 repo 同我講，先進行上傳。

## 清單

- [ ] 開一個空嘅 **private** GitHub repo
- [ ] 將 code 放上去（方法 A 或者 B）
- [ ] 俾 US$99 開 Apple Developer（個人名義），等批准電郵（通常 24–48 小時）
- [ ] 喺 Apple 登記 Bundle ID，喺 App Store Connect 開 app 記錄
- [ ] 開 App Store Connect API key（角色揀 **App Manager**）
- [ ] 將 4 個 secrets 加去 GitHub Actions
- [ ] 喺 Actions 撳 Run workflow，等 TestFlight build
- [ ] 用 TestFlight app 裝落 iPhone

未開 Developer 之前，都可以先做第 1、2 步。Code 一上到 GitHub，每次 push 都會自動喺雲端 Mac compile，同埋跑測試。呢步**唔使** Apple 帳戶，用嚟提早發現 SwiftUI 編譯錯誤。

---

## 1. 喺 GitHub 開一個空嘅 private repo

用 iPhone 開 Safari 或者 GitHub app：

1. 去 [https://github.com/new](https://github.com/new)，用 `kennychungvn` 登入。
2. **Repository name** 建議填 `big2-app`（之後文件入面嘅連結會用呢個名；你改第二個名都得，同我講一聲就得）。
3. 一定要揀 **Private**。之後會放入 API key 相關設定，唔好公開。
4. **唔好**剔 Add a README、Add .gitignore、Choose a license。空嘅 repo 先方便上傳。
5. 撳 **Create repository**。

---

## 2. 點樣將 code 放上 GitHub

揀一條路就得。建議用方法 A，用 iPhone 搞得掂，又唔使你自己上傳成百個檔案。

### 方法 A（建議）：用 device code 授權我喺呢部電腦幫你 push

你唔使部 Mac，亦唔使將 GitHub 密碼俾我。

1. 你開好上面嗰個空 repo，同我講 repo 名（例如 `big2-app`）。
2. 我會喺我部電腦跑 `gh auth login`，畫面會出一組一次性代碼，好似 `XXXX-XXXX`。
3. 你用 iPhone 去 [https://github.com/login/device](https://github.com/login/device)，登入 `kennychungvn`，輸入嗰組代碼。
4. 批准權限時，要包括 **repo**（私人 repo）同 **workflow**（Actions）。
5. 授權成功之後，我先會將 `main` branch 推上你個 private repo，然後即刻登出。我唔會幫你改 GitHub 設定，亦唔會加 secrets。

**而家未到呢一步。** 等你開好 repo 同我講，我先開始授權流程。

### 方法 B：用 GitHub 網頁自己上傳

如果你想自己放檔案：

1. 用我提供嘅 `big2-app.zip`（入面冇 `.git`），喺電腦解壓。
2. 打開你個空 repo 頁面，撳 **uploading an existing file**（或者 Add file → Upload files）。
3. 將解壓出嚟嘅**成個資料夾內容**拖入去（要見到 `.github`、`App`、`Package.swift` 呢啲喺 repo 根目錄，而唔係再包多一層 `big2-app/`）。
4. Commit 去 `main`。

呢步用電腦瀏覽器會容易好多。用 iPhone 上傳成個專案會好煩，所以更建議方法 A。

上傳之後，去 repo 嘅 **Actions** 頁睇下「iOS」呢個 workflow 有冇自動跑。第一次如果紅咗，將 log 畀我睇就得。

---

## 3. Apple Developer 批准之後：開 app 同 API key

等你收到 Apple 批准電郵先做呢部分。用開 Developer 嗰個 Apple ID 登入。

### 3.1 抄低 Team ID

1. 去 [https://developer.apple.com/account](https://developer.apple.com/account)。
2. 入 **Membership details**，入面有 **Team ID**（10 個英文字母／數字，好似 `AB12CD34EF`）。
3. 抄低，之後要放入 GitHub secret `APPLE_TEAM_ID`。

### 3.2 登記 Bundle ID

專案而家用嘅 Bundle ID 係 `com.kenny.daidee`，要喺 Apple 登記同一個。

1. 去 [Identifiers](https://developer.apple.com/account/resources/identifiers/list)。
2. 撳 **+** → 揀 **App IDs** → Continue → 揀 **App**。
3. Description 填 `Daidee Scoring` 或者 `鋤大Dee 計分`。
4. Bundle ID 揀 **Explicit**，填 `com.kenny.daidee`。
5. Capabilities 暫時唔使額外剔，Continue → Register。

如果系統話呢個 Bundle ID 已經被人用咗，**唔好亂改**，同我講，我幫你改 project 再出過。

### 3.3 喺 App Store Connect 開 app 記錄

1. 去 [https://appstoreconnect.apple.com](https://appstoreconnect.apple.com) → **My Apps** → **+** → **New App**。
2. Platforms 剔 **iOS**。
3. Name 填 `鋤大Dee 計分`（App Store 顯示名，之後都可以改）。
4. Primary Language 建議揀 **Chinese (Traditional)**。
5. Bundle ID 揀先先登記咗嘅 `com.kenny.daidee`。
6. SKU 填 `daidee-scoring`（只用嚟內部對帳，用家睇唔到）。
7. User Access 揀 **Full Access**。

暫時**唔使**填晒商店描述、截圖、私隱問卷。你自己用 TestFlight 內部試玩，唔使先過 App Review。

之後上架前，要喺 App Store Connect 將商品 id `com.kenny.daidee.removeads` 建成一個**非消耗性**內購（HK$8 永久移除廣告），同埋放私隱政策連結。條款同私隱政策草稿已經喺 `docs/terms.md`、`docs/privacy-policy.md`。

### 3.4 開 App Store Connect API key（角色揀 App Manager）

呢條 key 係俾 GitHub Actions 用嚟上傳 TestFlight，**唔係**你個 Apple ID 密碼。

1. 去 [App Store Connect API](https://appstoreconnect.apple.com/access/integrations/api)（Users and Access → Integrations → App Store Connect API）。
2. 第一次用要先同意條款，啟用 API。
3. 喺 **Team Keys** 撳 **Generate API Key**（或者 +）。
4. Name 填 `GitHub Actions TestFlight`。
5. Access 揀 **App Manager**。
6. 撳 Generate。
7. 頁頂有一個 **Issuer ID**（成個 team 共用，格式好似 UUID），抄低。
8. 抄低呢條 key 嘅 **Key ID**。
9. 撳 **Download API Key**，會下載 `AuthKey_XXXXXXXXXX.p8`。**只可以下載一次**，請存去 Files、iCloud Drive 或者密碼管理器。

千祈唔好將 `.p8` 傳到聊天、email，或者放進 Git。如果唔小心洩漏，去同一頁刪除（Revoke）再開一條新嘅。

如果之後上傳失敗，log 話權限唔夠，可以再開一條角色係 **Admin** 嘅 key 試（自動簽名有時要更高權限）。舊嗰條記得 Revoke。

### 3.5 將 4 個 secrets 加去 GitHub

用 iPhone 打開（如果 repo 名唔同，改埋網址）：

[https://github.com/kennychungvn/big2-app/settings/secrets/actions](https://github.com/kennychungvn/big2-app/settings/secrets/actions)

撳 **New repository secret**，加以下四個（Name 要一模一样）：

| Name | 值 |
| --- | --- |
| `ASC_KEY_ID` | API key 嘅 Key ID |
| `ASC_ISSUER_ID` | 頁頂嗰個 Issuer ID |
| `ASC_KEY_P8` | `.p8` 檔嘅內容（見下面） |
| `APPLE_TEAM_ID` | 10 位 Team ID |

`ASC_KEY_P8` 可以放兩種格式，workflow 兩樣都接受：

- **最方便（iPhone 建議）**：用 Files 或者備忘錄打開 `.p8`，全選複製，包括 `-----BEGIN PRIVATE KEY-----` 同 `-----END PRIVATE KEY-----`，直接貼入 secret。
- 或者將檔案做 **base64** 之後貼入（電腦先比較容易：`base64 -i AuthKey_XXXX.p8`）。

加完四個就得。GitHub 唔會再俾你睇返 secret 嘅內容，所以 Key ID / Issuer ID / Team ID 建議另外抄低。

---

## 4. 點樣觸發 TestFlight build

要先完成第 2 步（code 已喺 GitHub）。第 3 步嘅 secrets 未加齊都唔會出事：Job B 會自動跳過，workflow 唔會變紅色。

**方法 1：喺網頁手動跑（最常用）**

1. 去 repo → **Actions**。
2. 左邊揀 **iOS** 呢個 workflow。
3. 右邊撳 **Run workflow**，Branch 揀 `main`，再撳綠色 **Run workflow**。
4. 會先跑 Job A（模擬器 compile + 測試）。通過之後先跑 Job B（打包上傳 TestFlight）。

**方法 2：打 version tag**

之後出正式版可以開一個 tag，名要係 `v` 開頭，例如 `v0.1.0`。用 GitHub 網頁 **Releases → Create a new release** 開 tag 都會觸發 Job B。

Build number 會自動用 GitHub 嘅 `run_number`，你唔使每次自己改。版本號而家係 `0.1.0`。

第一次上傳有機會失敗，例如 Bundle ID 未登記、協議未同意、或者 API key 權限唔夠。將紅色 log 畀我睇，我幫你改。

亦都有機會第一次用自動簽名時，Apple 要你喺 [developer.apple.com](https://developer.apple.com/account) 同意最新嘅協議，同意完再跑一次就得。

---

## 5. 用 TestFlight 裝落 iPhone

1. 喺 App Store 裝 [TestFlight](https://apps.apple.com/app/testflight/id899247664)。
2. 用同一個 Apple ID 登入 [App Store Connect](https://appstoreconnect.apple.com) → 你個 app → **TestFlight**。
3. 將你自己加做 **Internal Tester**。個人帳戶入面，你自己已經係 Admin，通常將自己加落 Internal Testing 個 group 就得。
4. Build 上傳之後，Apple 要處理大概 5–15 分鐘（第一次可能更耐），處理完 TestFlight 頁面會顯示呢個 build 可以用。
5. iPhone 會收到 TestFlight 通知或者電郵，打開 TestFlight 撳安裝。

**Internal testers**（最多 100 個 App Store Connect 用戶）唔使過 beta review，你自己試玩用呢個就夠。

之後要俾朋友試，先加 **External testers**（用 email 邀請，最多 10,000 人）。第一個外部 build 要過一個簡單嘅 beta review，通常一兩日。朋友要先裝 TestFlight，再用邀請連結。

每個 build 用得 **90 日**，過期就要再出一個新 build。開發期間用 test ads，唔好叫人撳真廣告。

---

## 常見問題

- **Job B 話跳過、但成個 workflow 係綠色**：正常，即係仲未加齊四個 secrets。
- **Bundle ID 被用咗**：同我講，唔好自己亂改一半。
- **API key 下載唔返**：只可以下載一次；冇咗就 Revoke 再開一條，再更新 `ASC_KEY_ID` 同 `ASC_KEY_P8`。
- **簽名／權限錯誤**：試下用 **Admin** 角色再開一條 API key；或者去 developer.apple.com 睇下有冇協議要同意。
- **唔好**將 `.p8`、secrets、或者 Apple ID 密碼傳到聊天。

## 我同你點分工

- **你**：開 private repo、開 Apple Developer、登記 Bundle ID、開 app 記錄、開 API key、加 GitHub secrets、喺 Actions 撳 Run workflow、用 TestFlight 安裝。
- **我**：workflow 同文件已經準備好。等你授權 device code 之後先幫你 push。之後我會睇 build log，幫你改到可以裝落 iPhone。
