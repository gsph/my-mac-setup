# mac-setup

macOS 新帳號一鍵設定腳本。開好帳號後執行一次，完成所有系統設定、軟體安裝和開發環境建置。

支援 **macOS Tahoe (26+)** · **Apple Silicon (M 系列)**

-----

## 快速開始

**推薦：本機執行**（互動更穩定）

```bash
bash setup.sh
```

也可以用 `sh setup.sh` 或 `./setup.sh`：腳本開頭會自動偵測並用 `/bin/bash` 重新執行，不會因為 `sh`（POSIX 模式）而出現 `-e` 亂碼或語法錯誤。

**一行安裝**（從 GitHub 直接執行）

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/gsph/my-mac-setup/main/setup.sh)
```

-----

## 執行流程

```
1. 輸入基本資訊（每欄都帶入「目前系統值」當預設，直接 Enter 沿用）
   ├ 使用者名稱（顯示用，預設 = 目前帳號全名）
   ├ 外觀模式（預設 = 目前淺/深色）
   ├ 電腦名稱（僅管理員會被詢問，預設 = 目前電腦名稱）
   └ Git 設定（預設 = 目前 git config 的 user.name / email）
   ↓
2. 互動選單勾選要安裝的模組（全部預設勾選）
   ↓
3. 確認清單後全自動安裝
   ↓
4. 完成後顯示需手動完成的步驟，並同步輸出成 HTML
   （存到 ~/Desktop/mac-setup-todo.html，重開機後自動於瀏覽器開啟）
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
|螢幕保護     |20 分鐘啟動（密碼鎖定需手動設定，macOS 26 已移除舊 API）    |
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
|隱私權白名單   |把 op / Claude / Ghostty 寫入 TCC，減少反覆權限彈窗（寫不進去時退回手動）|

> 註：FileVault 已從腳本移除——Apple Silicon 新機在初次設定時通常就已開啟，且 recovery key 只在當初啟用時顯示一次、事後無法取回，交由系統處理即可。

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
- 設定檔寫入後，由 LaunchAgent 在重開機登入時自動重啟 Squirrel 觸發部署

**AI 工具**

- Claude Desktop（桌面 App）
- Claude CLI（`@anthropic-ai/claude-code`，需要 Node；勾選後會自動補勾 Node）

### Terminal & Shell

|項目       |說明                                                     |
|---------|-------------------------------------------------------|
|Ghostty  |GPU 加速 Terminal，Solarized Dark，JetBrains Mono Nerd Font|
|Oh My Zsh|Zsh 框架 + 精選 plugin                                     |
|Starship |現代 prompt，顯示 git 狀態、Python/Node 版本                     |
|Vim      |vim-plug + 10 個 plugin，Solarized Dark                  |

**Oh My Zsh Plugins**
`git` · `macos` · `history` · `colored-man-pages` · `1password`（裝了 op 才加）· `zsh-autosuggestions` · `zsh-syntax-highlighting` · `you-should-use` · `zsh-autocomplete`

> nvm 不放進 plugin 列表：`.zshrc` 已手動 source `nvm.sh`，加 plugin 會雙重載入。

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
|Docker Desktop          |容器執行環境（cask 安裝，需管理員權限）                              |
|Git                     |全域設定、global `.gitignore`、SSH config                 |
|1Password SSH Agent     |SSH 私鑰存於 1Password，git push 用 Touch ID 驗證           |
|Homebrew 自動更新           |LaunchAgent 每週日凌晨 3:00 執行 update + upgrade + cleanup|

-----

## Dock 圖示順序

只放有實際安裝的 App，沒裝的自動跳過（Finder 由系統固定在最左側）：

```
Finder · Safari · Chrome · Brave · Spotify
Ghostty · VS Code · Claude · Obsidian · 系統設定
```

-----

## 電腦名稱設定

只要**目前帳號在 `admin` 群組**就會詢問電腦名稱（電腦名稱是整台機器共用的設定）。

**詢問兩個名字**（皆帶入目前值當預設，Enter 沿用）

|名稱  |用在哪                        |範例         |
|----|---------------------------|-----------|
|顯示名稱|Finder、Find My、AirDrop     |`Philip M4`|
|網路名稱|終端機 prompt、`ping xxx.local`|`philip-m4`|

> 網路名稱只接受字母/數字/連字號，非法字元會自動轉成連字號，避免 HostName 與 LocalHostName 不一致。

-----

## 安裝後手動步驟

腳本完成後會在終端機顯示清單，並輸出成 `~/Desktop/mac-setup-todo.html`（可勾選、進度自動保存，**重開機後自動於瀏覽器開啟**）。

清單依「先把輸入裝置設好、後續操作才順手」的邏輯排序，固定順序大致如下（沒裝的項目自動略過）：

1. **Logi Options+** — 將 Lift Left 主按鍵對調為右手佈局
2. **鼠鬚管** — 系統設定 → 鍵盤 → 輸入來源 → 新增「鼠鬚管」（重開機後加入）
3. **螢幕保護** — 系統設定 → 鎖定畫面 → 要求密碼設為「立即」
4. **Raycast** — Preferences → 快捷鍵設為 Option+Space
5. **Ghostty** — 系統設定 → 隱私權與安全性 → 完整磁碟存取 → 新增 Ghostty
6. **1Password SSH Agent** — 設定 → Developer → 開啟 SSH Agent，完成後執行 `ssh -T git@github.com` 驗證
7. **1Password 瀏覽器設定** — 各瀏覽器裝擴充並改用 1Password（Chrome 與 Brave 共用 Chrome 線上應用程式商店，合併一條；Safari 走系統設定 → 自動填寫與密碼）
8. **Google Chrome 網頁 App** — 用 Chrome 把 Gmail（mail.google.com）、Google 日曆（calendar.google.com）做成獨立 App

-----

## 安裝軟體逐項說明

每個可選軟體的簡易說明（Safari 為 macOS 內建，不需安裝）。

### 瀏覽器

|軟體          |說明                                   |
|------------|-------------------------------------|
|Google Chrome|Google 的瀏覽器，擴充生態最完整                  |
|Brave       |基於 Chromium、內建廣告/追蹤阻擋的隱私瀏覽器           |

### 密碼 / 安全

|軟體            |說明                                            |
|--------------|----------------------------------------------|
|1Password     |密碼管理器（桌面 App），同時保管 SSH 金鑰                     |
|1Password CLI（op）|命令列工具，讓終端機/腳本存取 1Password；SSH Agent 與 OMZ 1password plugin 需要它|

### 音樂

|軟體     |說明      |
|-------|--------|
|Spotify|串流音樂服務|

### 生產力

|軟體            |說明                                         |
|--------------|-------------------------------------------|
|Rectangle     |用鍵盤快捷鍵把視窗排列/分割到螢幕各區                        |
|Raycast       |Spotlight 替代品，啟動器 + 剪貼簿/視窗/腳本等擴充           |
|Stats         |在選單列顯示 CPU / RAM / 網路 / 溫度等即時狀態            |
|Pearcleaner   |移除 App 時連同設定檔/殘留一起清乾淨                      |
|MonitorControl|用鍵盤調整外接螢幕亮度/音量（macOS 原生不支援外接螢幕亮度）         |
|Obsidian      |本機 Markdown 筆記 / 知識庫                       |

### 滑鼠

|軟體          |說明                            |
|------------|------------------------------|
|Logi Options+|Logitech 滑鼠/鍵盤官方驅動，自訂按鍵與手勢   |

### 輸入法

|軟體           |說明                            |
|-------------|------------------------------|
|鼠鬚管（Squirrel）|macOS 上的 RIME 中文輸入法引擎         |
|嘸蝦米（rime-liur）|建構於 RIME 之上的嘸蝦米輸入方案           |

### 終端機 & Shell

|軟體                     |說明                                  |
|-----------------------|------------------------------------|
|Ghostty                |GPU 加速、現代的終端機模擬器                    |
|JetBrains Mono Nerd Font|等寬程式字型，內含 Nerd Font 圖示（給 prompt/編輯器）|
|Oh My Zsh              |Zsh 設定框架，管理 plugin 與主題             |
|Starship               |跨 shell 的現代 prompt，顯示 git/語言版本等    |
|Vim                    |終端機文字編輯器，搭 vim-plug 管理外掛           |

### 編輯器

|軟體               |說明                |
|-----------------|------------------|
|Visual Studio Code|微軟的圖形化程式編輯器     |

### AI 工具

|軟體                              |說明                                |
|--------------------------------|----------------------------------|
|Claude Desktop                  |Anthropic Claude 的桌面 App          |
|Claude CLI（@anthropic-ai/claude-code）|終端機裡的 Claude Code 代理工具（需 Node）|

### 開發環境（CLI 工具與相依）

|軟體                       |說明                                       |
|-------------------------|-----------------------------------------|
|Homebrew                 |macOS 套件管理器，本腳本用它安裝大部分軟體                 |
|pyenv / pyenv-virtualenv |管理多個 Python 版本與虛擬環境                      |
|Python（最新穩定版）            |由 pyenv 編譯安裝                             |
|nvm                      |管理多個 Node.js 版本                          |
|Node 24 LTS              |JavaScript 執行環境                          |
|pnpm                     |快速、省空間的 Node 套件管理器                       |
|Docker Desktop           |在 macOS 上跑容器（Docker Engine + CLI + GUI，cask 安裝）   |
|openssl@3 / readline / sqlite / xz / zlib|pyenv 編譯 Python 所需的相依函式庫     |

-----

## 技術設計重點

### 安全模式

腳本使用 `set -euo pipefail`：`-e` 任何指令失敗即停、`-u` 抓未定義變數、`-o pipefail` 抓 pipeline 失敗。`menu_is_on` 全部以 `if/then/fi` 呼叫，與 `set -e` 相容。

### Locale 與全形字解析（本次重點修正）

終端機常送出無效的 `LC_ALL=UTF-8`（"UTF-8" 不是合法 locale 名稱），會讓 bash 進入多位元組解析卻無對應 ctype 表，導致 **未加大括號的 `$VAR` 緊鄰全形字（如 `$VAR（`）把全形字位元組吃進變數名**，報 `unbound variable`。

- **真正解法**：變數一律用 `${VAR}`，尤其後面緊接中文/全形標點時——本檔已全面採用。
- 另外在開頭把 locale 正規化成 `en_US.UTF-8`（給 sed/grep/tr 等執行期工具用）；但實測這不能修掉「解析期」的全形字 bug，`${VAR}` 才是關鍵。

### sh / POSIX 模式相容

開頭偵測非 bash 或 POSIX 模式（`sh setup.sh` 會讓 bash 進 POSIX 模式、`echo -e` 失效），自動 `exec /bin/bash` 重新執行，避免 `-e` 亂碼。

### sudo 維持

確認後寫入暫時 NOPASSWD sudoers 規則（`/etc/sudoers.d/...`），整個安裝期間不再反覆要密碼；腳本結束（含異常）由 `trap` 自動移除。macOS 的 `tty_tickets` 讓背景 keepalive loop 無效，故改用此法。

### 一般使用者（非管理員）相容 + 管理員在旁協助授權

非管理員帳號沒有 `sudo` 權限，而 Homebrew、應用程式（cask）、Xcode CLT 與系統設定都需要管理員權限。腳本對此分兩段處理：

1. **請管理員在旁協助授權（推薦）**：偵測到非管理員時，腳本會問是否請管理員協助。若同意，會跳出 macOS 原生的「以管理員身分執行」對話框——這個對話框**接受任何管理員的帳密，即使目前登入的是一般使用者**。管理員輸入一次帳密後，腳本以 root 寫入一條暫時 NOPASSWD sudoers 規則（`/etc/sudoers.d/...`），讓這個帳號**在安裝期間取得 `sudo`**，於是 Homebrew / Xcode CLT / cask / 系統設定全部能正常安裝。腳本結束（含異常）由 `trap` 自動移除規則，帳號**恢復原本的非管理員狀態，不留後門**。

2. **未授權則優雅降級**：若使用者選擇不請管理員協助、或授權未通過，腳本**不會中止**，而是自動略過所有需要權限的步驟（Homebrew、Xcode CLT、cask 應用程式、電腦名稱、時區、自動更新、防火牆、Ghostty FDA），只進行不需權限的使用者層設定（dotfiles、Oh My Zsh、Vim、Git/SSH 設定等），並把略過項目列入最後的「手動補完清單」。`brew_pkg` / `brew_cask` 也會在 Homebrew 不存在時自動略過，避免一連串安裝失敗的噪音。

> 技術實作：管理員與非管理員最終都走同一條「暫時 NOPASSWD sudoers」路徑，差別只在取得方式——管理員用 `sudo -v`，非管理員用 `osascript ... with administrator privileges`。macOS 預設 `tty_tickets` 讓背景 keepalive loop 無效，故用 NOPASSWD 規則取代。

### 輸入帶預設值

基本資訊每一欄都先讀目前系統值（`id -F`、`AppleInterfaceStyle`、`scutil --get`、`git config`）當預設，直接 Enter 沿用、要改才輸入（`ask_default` 輔助函數）。

### 防呆設計

- **選單引擎**：純 bash、零依賴，標題不佔編號。
- **Dock 圖示**：在所有套件安裝**之後**才設定，確保 App 已存在。
- **設定檔備份**：覆蓋 `.zshrc` / `.vimrc` / Ghostty / Starship / VS Code / SSH config / `.gitignore_global` 等前，先建立時間戳備份（`backup_if_exists`）。
- **SSH config**：`IdentityAgent` 用 `$HOME` 完整路徑（SSH 不展開 `~`），註解獨立行。
- **安裝函數**：`brew_pkg` / `brew_cask` / `zsh_plugin` 安裝失敗只警告、不中止後續流程。
- **Pipeline 保護**：命令替換含 pipeline 都用 `|| true` 收尾並對結果保底，避免 pipefail 中止；`pyenv install --skip-existing` 取代易出錯的舊偵測邏輯。
- **手動清單 → HTML**：步驟輸出成桌面 HTML（可勾選、localStorage 保存進度），一次性 LaunchAgent 在重開機登入時自動於瀏覽器開啟，開完自我移除。
- **LaunchAgent**：先 `launchctl bootout` 再 `bootstrap`，重複執行也能套用最新 plist。

-----

## 注意事項

- 腳本不涉及帳號建立，請先手動建立目標帳號後再執行
- 腳本不含任何個人資訊，所有私人資料在執行時輸入
- 大型套件安裝時間較長（Chrome、VS Code 等可能要幾分鐘），請耐心等待
- 執行完畢後建議重新啟動電腦（部分系統設定與輸入法部署、手動清單 HTML 都在重開機後生效/開啟）
