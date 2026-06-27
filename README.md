# mac-setup

macOS 新帳號一鍵設定腳本。開好帳號後執行一次，完成所有系統設定、軟體安裝和開發環境建置。

支援 **macOS Tahoe (15+)** · **Apple Silicon (M 系列)**

-----

## 快速開始

**推薦：本機執行**（互動更穩定）

```bash
bash setup.sh
```

**一行安裝**（從 GitHub 直接執行）

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/gsph/mac-setup/setup.sh)
```

-----

## 執行流程

```
1. 輸入基本資訊
   ├ 使用者名稱（顯示用）
   ├ 電腦名稱（僅唯一管理員會被詢問）
   ├ 外觀模式（淺色 / 深色）
   └ Git 設定（user.name / email）
   ↓
2. 互動選單勾選要安裝的模組（全部預設勾選）
   ↓
3. 確認清單後全自動安裝
   ↓
4. 完成後顯示需手動完成的步驟清單
```

-----

## 互動選單操作

|鍵                  |動作      |
|-------------------|--------|
|數字                 |切換單一項目勾選|
|空格分隔多個數字（例：`1 3 5`）|一次切換多個  |
|`A`                |全選      |
|`N`                |全不選     |
|`Enter`            |確認進入下一步 |

-----

## 模組總覽

### 系統設定（19 項）

|項目       |說明                                          |
|---------|--------------------------------------------|
|語言       |繁體中文第一、英文第二，UTF-8                           |
|按鍵速度     |75% 快（KeyRepeat=2, InitialKeyRepeat=25）     |
|自然捲動     |關閉，恢復傳統方向                                   |
|觸控板      |點一下來選按                                      |
|Dock     |底部、自動隱藏、縮放效果                                |
|螢幕保護     |20 分鐘啟動，睡眠後立即要求密碼                           |
|熱角       |左上=螢幕保護 / 右上=桌面 / 左下=應用程式視窗 / 右下=指揮中心       |
|截圖       |存入 `~/Desktop/Screenshots`，PNG，無陰影          |
|Finder   |路徑列、狀態列、副檔名、清單檢視、Home 為新視窗預設                |
|選單列      |藍芽、音量、電池百分比（自動偵測有無電池）                       |
|桌面       |素色岩石色                                       |
|鍵盤       |外接鍵盤 Command ↔ Option 互換（LaunchAgent 開機自動套用）|
|Spotlight|停用，輸入法切換改為 Command+Space                    |
|顯示器      |關閉選單列鏡象輸出選項                                 |
|.DS_Store|不寫入網路磁碟和 USB 外接硬碟                           |
|時區       |台北，網路自動同步                                   |
|自動更新     |macOS 自動下載並安裝更新                             |
|防火牆      |開啟，含隱身模式                                    |
|FileVault|全磁碟加密，提示存入 Recovery Key                     |

### 應用程式

**瀏覽器**

- Google Chrome · Brave
- Safari 為內建，自動加入 Dock

**密碼 / 安全**

- 1Password（桌面 App）
- 1Password CLI（`op` 指令，Oh My Zsh plugin 和 SSH agent 需要）

**音樂**

- Spotify

**生產力**

|App           |說明                                    |
|--------------|--------------------------------------|
|Rectangle     |視窗管理，鍵盤快速排列                           |
|Raycast       |啟動器，取代 Spotlight（手動設定快捷鍵 Option+Space）|
|Stats         |Menubar 顯示 CPU / RAM / 網路             |
|Pearcleaner   |App 完整移除，不留殘檔                         |
|MonitorControl|外接螢幕亮度控制                              |
|Obsidian      |Markdown 知識庫                          |

**滑鼠**

- Logi Options+（Logitech 滑鼠驅動）

**輸入法**

- 鼠鬚管（Squirrel）+ 嗯蝦米（rime-liur）

### Terminal & Shell

|項目       |說明                                                     |
|---------|-------------------------------------------------------|
|Ghostty  |GPU 加速 Terminal，Solarized Dark，JetBrains Mono Nerd Font|
|Oh My Zsh|Zsh 框架 + 10 個精選 plugin                                 |
|Starship |現代 prompt，顯示 git 狀態、Python/Node 版本                     |
|Vim      |vim-plug + 10 個 plugin，Solarized Dark                  |

**Oh My Zsh Plugins**
`git` · `macos` · `history` · `colored-man-pages` · `1password` · `nvm` · `zsh-autosuggestions` · `zsh-syntax-highlighting` · `you-should-use` · `zsh-autocomplete`

**Vim Plugins**
`vim-colors-solarized` · `vim-airline` · `vim-airline-themes` · `nerdtree` · `vim-gitgutter` · `vim-fugitive` · `ale` · `indentLine` · `vim-commentary` · `auto-pairs`

### 編輯器

VS Code + `settings.json` + 6 個擴充功能：
`ms-python.python` · `eamodio.gitlens` · `redhat.vscode-yaml` · `vscodevim.vim` · `1Password.op-vscode` · `esbenp.prettier-vscode`

### 開發環境

|項目                      |說明                                                  |
|------------------------|----------------------------------------------------|
|pyenv + pyenv-virtualenv|Python 版本管理，自動安裝最新穩定版                               |
|nvm + Node 24 LTS + pnpm|Node 版本管理                                           |
|Git                     |全域設定、global `.gitignore`、SSH config                 |
|1Password SSH Agent     |SSH 私鑰存於 1Password，git push 用 Touch ID 驗證           |
|Homebrew 自動更新           |LaunchAgent 每週日凌晨 3:00 執行 update + upgrade + cleanup|

-----

## Dock 圖示順序

只放有實際安裝的 App，沒裝的自動跳過：

```
Finder · Safari · Chrome · Brave · Spotify
Ghostty · VS Code · Obsidian · 系統設定
```

-----

## 電腦名稱設定

腳本會自動判斷是否詢問電腦名稱：

**滿足兩個條件才會詢問**

1. 目前帳號在 `admin` 群組
1. 整台機器只有一個管理員

兩個都成立才詢問，因為電腦名稱是整台機器共用的設定，多管理員的情況下隨意修改會干擾其他帳號。

**詢問兩個名字**

|名稱  |用在哪                        |範例         |
|----|---------------------------|-----------|
|顯示名稱|Finder、Find My、AirDrop     |`Philip M4`|
|網路名稱|終端機 prompt、`ping xxx.local`|`philip-m4`|

-----

## 安裝後手動步驟

腳本完成後會顯示完整清單，主要包含：

**輸入法**

- 系統設定 → 鍵盤 → 輸入來源 → 新增「鼠鬚管」
- 選單列鼠鬚管圖示 → 重新部署（讓嗯蝦米方案生效）

**啟動器**

- Raycast → Preferences → General → 快捷鍵設為 Option+Space

**1Password**

- 設定 → Developer → 開啟 SSH Agent
- 建立 SSH Key（Ed25519）→ 加入 GitHub
- 測試：`ssh -T git@github.com`
- Chrome / Brave 安裝 1Password 擴充功能（若有裝）
- 確認 FileVault Recovery Key 存入 1Password（若有開啟）

**滑鼠**

- Logi Options+ 將 Lift Left 主按鍵對調為右手佈局

**其他**

- Finder → 設定 → 側邊欄，手動勾選 iCloud Drive、AirDrop、外接硬碟等
- Safari → File → Add to Dock → calendar.google.com（Google Calendar）
- Vim 若 plugin 未自動安裝，執行 `:PlugInstall`

-----

## 技術設計重點

### 安全模式

腳本使用 `set -euo pipefail`：

- `-e`：任何指令失敗立即停止
- `-u`：抓未定義變數
- `-o pipefail`：抓 pipeline 中的失敗

`menu_is_on` 全部使用 `if/then/fi` 形式呼叫，與 `set -e` 完全相容。

### 防呆設計

**選單引擎**：純 bash 實作，零外部依賴。標題不佔編號，數字輸入精確對應顯示編號。

**Dock 圖示**：在所有套件安裝**之後**才設定，確保 App 已存在，`add_dock_app` 的路徑檢查才能成功。

**SSH config**：`IdentityAgent` 使用 `$HOME` 完整路徑（SSH 不展開 `~`），註解獨立行（SSH 不支援行內註解）。

**安裝函數**：`brew_pkg` / `brew_cask` / `zsh_plugin` 全部用 `if/else` + `return 0`，避免 `&&...||` 邏輯炸彈，安裝失敗不中止後續流程。

**Pipeline 保護**：所有命令替換 `$(...)` 含 pipeline 都加 `|| true` 或 `|| echo 0`，避免 pipefail 下因中間段失敗中止腳本。

**電池偵測**：用 `pmset -g batt | grep -q "InternalBattery"`，比 `system_profiler` 更可靠。

**LaunchAgent**：優先用 macOS 13+ 的 `launchctl bootstrap`，舊版 `launchctl load` 為 fallback。

**Vim colorscheme**：用 `silent! colorscheme solarized`，避免 plugin 還沒下載前報錯。

**Oh My Zsh nvm plugin**：`NVM_DIR` 必須在 `source omz` 之前 export，否則 plugin 載入時找不到。

-----

## 注意事項

- 腳本不涉及帳號建立，請先手動建立目標帳號後再執行
- 腳本不含任何個人資訊，所有私人資料在執行時輸入
- 執行過程中可能多次要求 `sudo` 密碼
- 大型套件安裝時間較長（Chrome、VS Code 等可能要幾分鐘），請耐心等待
- 執行完畢後建議重新啟動電腦