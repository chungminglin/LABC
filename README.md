# LABC NeverStand -iOS
NeverStand 是一款設計專用為台北捷運 iOS 應用程式。我們利用藍牙 Beacon 技術自動偵測使用者所在的捷運站與月台，並結合台北捷運的車廂擁擠度（車重）資料，即時運算並建議使用者前往最空曠的車廂候車，大幅增加有座位的機率。

# 🌟 模組功能
1. 自動偵測所在站點：透過掃描捷運站內的藍牙 Beacon裝置，自動識別當前所在的車站名稱與位置。
2. 智慧判斷月台位置：程式碼中包含邏輯判斷（如偵測 PAO 關鍵字），確認使用者是否已進入月台層，精準觸發查詢。
3. 即時擁擠度查詢：串接台北捷運公開 API (CarWeight.asmx)，獲取即時的列車車廂擁擠度數據。
4. 最佳車廂建議：透過演算法 (CartRanking) 對各車廂擁擠度進行排序，提供「最佳上車車廂」建議。
5. 方向指引：根據車站 ID 與月台編號，自動判斷並顯示列車行駛方向（如：往淡水、往象山等）。
6. 背景通知：支援背景執行，當偵測到最佳車廂時，發送推播通知提醒使用者。
7. 智慧省電模式：偵測到月台並獲取資料後，會自動暫停掃描 90 分鐘，避免過度消耗電力。

# 🛠 技術架構
### 核心技術
* CoreLocation (iBeacon)：用於背景掃描與偵測捷運站的 Beacon 訊號。
* URLSession & Network：處理 SOAP (XML) 與 JSON 格式的 API 請求。
* UserNotifications：發送本地推播通知。
* SwiftUI：建構現代化的使用者介面。
### 外部資料來源 (API)
* Beacon 資訊：將掃描到的 Beacon UUID/Major/Minor 轉換為車站與月台資訊。
* 車廂擁擠度 (車重) ：獲取指定車站的即時車廂載重數據。

# 📱 安裝與執行需求
### 系統需求
* Xcode: 建議使用最新版本 (支援 iOS 18+ SDK)。
* iOS: 18.2 或更高版本 (Deployment Target)。
* 硬體: 支援藍牙與定位功能的 iPhone。
### 權限設定
為了讓 App 正常運作，需要在 Info.plist 中開啟以下權限：
- Privacy - Location Always and When In Use Usage Description：用於背景偵測 Beacon。
- Privacy - Bluetooth Always Usage Description：用於掃描藍牙訊號。
- Background Modes：需開啟 Location updates 與 Bluetooth LE accessories (bluetooth-central)。
### 安裝步驟
Clone 此專案到本地端。
使用 Xcode 開啟 .xcodeproj。

### ⚠️ 重要設定：
專案中的 CarWeightAPIService.swift 與 BeaconAPIService.swift 目前包含範例ID。
若要實際部署或長期使用，請替換為您自己的台北捷運 API 憑證。
BeaconManager.swift 中設定了特定的 Beacon UUID，請確認這是否符合您要測試的場域。
連接實體 iPhone 裝置（模擬器無法測試藍牙功能）。建置並執行 (Cmd + R)。
### 📂 專案結構說明
```
NeverStandApp.swift:程式進入點，初始化 BeaconManager。
├─核心邏輯
│　├─BeaconManager.swift: 專案的核心控制器。負責處理權限、掃描 Beacon、背景任務管理以及觸發 API 呼叫流程。
│　└─CartRanking.swift: 包含車廂排序演算法，決定哪一個車廂最適合上車。
│ 
│─API 服務
│　├─BeaconAPIService.swift: 負責與 Beacon 資訊 API 通訊。
│　└─CarWeightAPIService.swift: 負責與車廂擁擠度 API 通訊，與 JSON 解析。
│
└─UI 介面
　　└─ContentView.swift: 主畫面。包含掃描開關、狀態顯示以及建議車廂列表的 UI。
```

---

# 🤖 LABC NeverStand - Android
Android版本已建立基礎架構。
[.apk檔案。位置下載連結](https://drive.google.com/drive/folders/1-dTGtNrr_9qGooFFZiYj494NEfg7nbHP)

### 核心技術與環境
* **開發語言與建置**：使用 Kotlin 開發，並採用 Gradle (Kotlin DSL, `build.gradle.kts`) 作為專案的建置系統。
* **藍牙與定位**：應用 Android 原生的 Bluetooth LE API 與定位服務，進行 Beacon 訊號掃描與背景偵測。

### 安裝與執行指引
1. **取得程式碼**：將本專案 Clone 至本地端，並確認切換至 `android` 分支。
2. **開啟專案**：建議使用最新版本的 **Android Studio** 開啟專案資料夾。
3. **權限設定**：Android 版本同樣需要宣告並請求藍牙與定位權限，請確保實體測試裝置已開啟相關設定（如 `ACCESS_FINE_LOCATION`、`BLUETOOTH_SCAN` 等）。
4. **實機測試**：由於 Android 模擬器無法完整支援藍牙 Beacon 掃描功能，請務必連接實體 Android 手機進行編譯與測試。