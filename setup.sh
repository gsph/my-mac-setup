#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════════
#  macOS Setup Script
#  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  新帳號開好後執行，一次完成系統設定、軟體安裝和開發環境建置
#
#  支援：macOS Tahoe (15+) · Apple Silicon (M 系列)
#
#  執行方式（推薦本機，互動更穩定）：
#    bash setup.sh
#
#  一行安裝（從 GitHub 直接執行）：
#    bash <(curl -fsSL https://raw.githubusercontent.com/YOUR_USER/mac-setup/main/setup.sh)
#
#  注意：腳本不含任何個人資訊，所有私人資料在執行時輸入
# ════════════════════════════════════════════════════════════════════

# ─── 安全模式說明 ────────────────────────────────────────────────
# set -e：任何指令失敗立即停止，避免錯誤疊加
# set -u：抓未定義變數
# set -o pipefail：抓 pipeline 中的失敗
# 注意：menu_is_on 全部用 if/then/fi 改寫，set -e 下安全
set -euo pipefail


# ════════════════════════════════════════════════════════════════════
#  區塊 1：終端機輸出工具
# ════════════════════════════════════════════════════════════════════

# 顏色：成功=綠 / 警告=黃 / 資訊=藍 / 錯誤=紅
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly DIM='\033[2m'
readonly NC='\033[0m'

log()  { echo -e "${GREEN}✓${NC} $1"; }
warn() { echo -e "${YELLOW}⚠${NC}  $1"; }
info() { echo -e "${BLUE}→${NC} $1"; }
fail() { echo -e "${RED}✗ 錯誤：${NC}$1"; exit 1; }

section() {
  echo -e "\n${BOLD}${CYAN}══════════════════════════════${NC}"
  echo -e "${BOLD}${CYAN}  $1${NC}"
  echo -e "${BOLD}${CYAN}══════════════════════════════${NC}"
}

# 收集腳本無法自動化的步驟，最後統一顯示
MANUAL_STEPS=()
add_manual() { MANUAL_STEPS+=("$1"); }


# ════════════════════════════════════════════════════════════════════
#  區塊 2：互動式選單引擎（純 bash，零依賴）
#
#  資料結構：三個平行陣列同步操作
#    MENU_KEYS[]   程式識別碼（英文）
#    MENU_LABELS[] 顯示文字（中文）
#    MENU_STATE[]  勾選狀態（"1"=勾選 / "0"=未勾選）
#
#  區塊標題用 "__SECTION__標題" 前綴，不可選取
# ════════════════════════════════════════════════════════════════════

MENU_KEYS=()
MENU_LABELS=()
MENU_STATE=()

# 新增選單項目
# 用法：menu_add "key" "顯示文字" [預設狀態 1|0，預設 1]
menu_add() {
  local key=$1 label=$2 state=${3:-1}
  MENU_KEYS+=("$key")
  MENU_LABELS+=("$label")
  MENU_STATE+=("$state")
}

# 查詢某個 key 是否被勾選（exit 0=是 / exit 1=否）
# 用法：if menu_is_on "key"; then ...; fi
menu_is_on() {
  local target=$1 i
  for i in "${!MENU_KEYS[@]}"; do
    if [[ "${MENU_KEYS[$i]}" == "$target" ]] && [[ "${MENU_STATE[$i]}" == "1" ]]; then
      return 0
    fi
  done
  return 1
}

# 顯示互動選單，使用者按 Enter 確認後離開
menu_run() {
  local title=$1
  local display_num count key label state num i input

  while true; do
    clear
    echo
    echo -e "${BOLD}${CYAN}  $title${NC}"
    echo -e "  ${DIM}數字鍵切換勾選 · 空格分隔多選（例：1 3 5）· A=全選 · N=全不選 · Enter=確認${NC}"
    echo

    # 顯示所有項目（標題不編號，普通項目用獨立計數器避免跳號）
    display_num=0
    for i in "${!MENU_KEYS[@]}"; do
      key="${MENU_KEYS[$i]}"
      label="${MENU_LABELS[$i]}"
      state="${MENU_STATE[$i]}"

      if [[ "$key" == __SECTION__* ]]; then
        echo -e "\n  ${BOLD}── ${key#__SECTION__} ${NC}"
        continue
      fi

      display_num=$((display_num + 1))
      if [[ "$state" == "1" ]]; then
        echo -e "  ${GREEN}[x]${NC} ${BOLD}${display_num})${NC} $label"
      else
        echo -e "  ${DIM}[ ]${NC} ${BOLD}${display_num})${NC} $label"
      fi
    done

    echo
    read -rp "  輸入 [數字/A/N/Enter]: " input

    case "$input" in
      "")
        break
        ;;
      [Aa])
        # 全選：所有非標題項目設為勾選
        for i in "${!MENU_KEYS[@]}"; do
          if [[ "${MENU_KEYS[$i]}" != __SECTION__* ]]; then
            MENU_STATE[$i]=1
          fi
        done
        ;;
      [Nn])
        # 全不選
        for i in "${!MENU_KEYS[@]}"; do
          if [[ "${MENU_KEYS[$i]}" != __SECTION__* ]]; then
            MENU_STATE[$i]=0
          fi
        done
        ;;
      *)
        # 數字輸入：根據顯示編號（非陣列索引）找到對應項目切換
        for num in $input; do
          if ! [[ "$num" =~ ^[0-9]+$ ]] || [[ "$num" -le 0 ]]; then
            continue
          fi
          count=0
          for i in "${!MENU_KEYS[@]}"; do
            if [[ "${MENU_KEYS[$i]}" == __SECTION__* ]]; then
              continue
            fi
            count=$((count + 1))
            if [[ "$count" -eq "$num" ]]; then
              if [[ "${MENU_STATE[$i]}" == "1" ]]; then
                MENU_STATE[$i]=0
              else
                MENU_STATE[$i]=1
              fi
              break
            fi
          done
        done
        ;;
    esac
  done
}


# ════════════════════════════════════════════════════════════════════
#  區塊 3：套件安裝輔助函數
#
#  brew_pkg()  安裝 CLI 工具（formula）
#  brew_cask() 安裝圖形介面 App（cask）
#
#  設計：
#  - 先檢查是否已安裝，避免重複動作
#  - 用 if/else 而非 &&...|| 避免邏輯炸彈
#  - 永遠 return 0，避免函數失敗中止後續流程
#  - 保留 stdout 讓使用者看到下載進度（大套件可能要好幾分鐘）
# ════════════════════════════════════════════════════════════════════

brew_pkg() {
  local pkg=$1
  if brew list "$pkg" &>/dev/null; then
    log "$pkg 已安裝"
    return 0
  fi
  info "安裝 $pkg..."
  if brew install "$pkg"; then
    log "$pkg ✓"
  else
    warn "$pkg 安裝失敗"
  fi
  return 0
}

brew_cask() {
  local cask=$1
  if brew list --cask "$cask" &>/dev/null; then
    log "$cask 已安裝"
    return 0
  fi
  info "安裝 $cask..."
  if brew install --cask "$cask"; then
    log "$cask ✓"
  else
    warn "$cask 安裝失敗"
  fi
  return 0
}


# ════════════════════════════════════════════════════════════════════
#  區塊 4：Dock 圖示輔助函數
#
#  - 全域定義（不在 if 區塊內），讓套件安裝後仍可呼叫
#  - 只有 App 路徑實際存在才加入，避免空白圖示
#  - XML 必須在同一行，避免換行造成 plist 格式錯誤
# ════════════════════════════════════════════════════════════════════

add_dock_app() {
  local app_path=$1
  if [ ! -e "$app_path" ]; then
    return 0
  fi
  defaults write com.apple.dock persistent-apps -array-add "<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>$app_path</string><key>_CFURLStringType</key><integer>0</integer></dict></dict></dict>"
}


# ════════════════════════════════════════════════════════════════════
#  區塊 5：歡迎畫面 + 基本資訊輸入
# ════════════════════════════════════════════════════════════════════

clear
echo
echo -e "${BOLD}${CYAN}"
echo "  ╔══════════════════════════════════════════╗"
echo "  ║        macOS Setup Script                ║"
echo "  ║        Tahoe (15+) · Apple Silicon       ║"
echo "  ╚══════════════════════════════════════════╝"
echo -e "${NC}"

section "基本資訊"
echo

read -rp "  使用者名稱（用於顯示）: " USER_DISPLAY_NAME
read -rp "  外觀模式 [l=淺色 / d=深色]: " APPEARANCE_INPUT

case "$APPEARANCE_INPUT" in
  [Dd]) APPEARANCE="dark" ;;
  *)    APPEARANCE="light" ;;
esac

# ── 電腦名稱（只有唯一管理員才詢問）──
# 判斷 1：目前帳號是否在 admin 群組
IS_ADMIN=false
if groups | grep -q "admin"; then
  IS_ADMIN=true
fi

# 判斷 2：目前帳號是否是唯一管理員
# 注意：用 || echo 0 保護整個 pipeline，避免 pipefail+set -e 下因 dscl 失敗而中止
ADMIN_COUNT=$(dscl . -read /Groups/admin GroupMembership 2>/dev/null \
  | tr ' ' '\n' \
  | grep -v "^GroupMembership:" \
  | grep -v "^$" \
  | wc -l \
  | tr -d ' ' \
  || echo 0)
IS_ONLY_ADMIN=false
if [ "$ADMIN_COUNT" = "1" ]; then
  IS_ONLY_ADMIN=true
fi

# 兩個條件都成立才詢問電腦名稱
COMPUTER_DISPLAY_NAME=""   # Finder / Find My 顯示（可有空格，例如 Philip's M4）
COMPUTER_NETWORK_NAME=""   # 終端機 / 網路用（不可有空格，例如 philip-m4）

if [ "$IS_ADMIN" = "true" ] && [ "$IS_ONLY_ADMIN" = "true" ]; then
  echo
  echo -e "  ${BOLD}電腦名稱設定${NC}"
  echo -e "  ${DIM}（你是唯一管理員，可以設定電腦名稱）${NC}"
  read -rp "  顯示名稱（Finder / Find My，可含空格，例如 Philip M4）: " COMPUTER_DISPLAY_NAME
  read -rp "  網路名稱（終端機 / ping，不可含空格，例如 philip-m4）: " COMPUTER_NETWORK_NAME
else
  warn "非管理員或非唯一管理員，跳過電腦名稱設定"
fi

echo
echo -e "  ${BOLD}Git 設定${NC}（留空則跳過）"
read -rp "  Git user.name: " GIT_NAME
read -rp "  Git email: " GIT_EMAIL

# 確認摘要
echo
echo -e "  確認："
echo -e "  名稱：${BOLD}$USER_DISPLAY_NAME${NC}"
if [ -n "$COMPUTER_DISPLAY_NAME" ]; then
  echo -e "  顯示名稱：${BOLD}$COMPUTER_DISPLAY_NAME${NC}"
  echo -e "  網路名稱：${BOLD}$COMPUTER_NETWORK_NAME${NC}"
fi
if [ "$APPEARANCE" = "light" ]; then
  echo -e "  外觀：淺色"
else
  echo -e "  外觀：深色"
fi
if [ -n "$GIT_NAME" ]; then
  echo -e "  Git：${BOLD}$GIT_NAME${NC} <$GIT_EMAIL>"
fi
echo

read -rp "  繼續？[y/N] " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
  echo "已取消。"
  exit 0
fi


# ════════════════════════════════════════════════════════════════════
#  區塊 6：建立選單
# ════════════════════════════════════════════════════════════════════

# ── 系統設定 ──
menu_add "__SECTION__系統設定" ""
menu_add "sys_lang"            "語言：繁中 > 英文 + UTF-8"
menu_add "sys_keyrepeat"       "按鍵速度（75% 快）"
menu_add "sys_scroll"          "關閉自然捲動（觸控板 + 滑鼠）"
menu_add "sys_trackpad"        "觸控板：點一下來選按"
menu_add "sys_dock"            "Dock（底部、自動隱藏、縮放效果）"
menu_add "sys_screensaver"     "螢幕保護（20 分鐘）+ 睡眠立即要求密碼"
menu_add "sys_hotcorner"       "熱角（左上=螢幕保護 / 右上=桌面 / 左下=應用程式視窗 / 右下=指揮中心）"
menu_add "sys_screenshot"      "截圖資料夾（Desktop/Screenshots）"
menu_add "sys_finder"          "Finder（路徑列、副檔名、最近使用）"
menu_add "sys_menubar"         "選單列（藍芽、音量、電池百分比）"
menu_add "sys_wallpaper"       "桌面：素色岩石色"
menu_add "sys_keyboard_remap"  "外接鍵盤 Command ↔ Option 互換"
menu_add "sys_spotlight"       "Spotlight 停用 + 輸入法 Command+Space"
menu_add "sys_mirror"          "顯示器：關閉鏡象輸出選項"
menu_add "sys_ds_store"        "停止在網路/外接磁碟產生 .DS_Store"
menu_add "sys_timezone"        "時區：台北（網路自動同步）"
menu_add "sys_autoupdate"      "macOS 自動更新"
menu_add "sys_firewall"        "防火牆開啟"
menu_add "sys_filevault"       "FileVault 磁碟加密"

# ── 瀏覽器 ── (Safari 是內建，自動加入 Dock)
menu_add "__SECTION__瀏覽器" ""
menu_add "app_chrome"     "Google Chrome"
menu_add "app_brave"      "Brave"

# ── 密碼 / 安全 ──
menu_add "__SECTION__密碼 / 安全" ""
menu_add "app_1password"  "1Password"

# ── 音樂 ──
menu_add "__SECTION__音樂" ""
menu_add "app_spotify"    "Spotify"

# ── 生產力 ──
menu_add "__SECTION__生產力" ""
menu_add "app_rectangle"      "Rectangle（視窗管理）"
menu_add "app_raycast"        "Raycast（啟動器，取代 Spotlight）"
menu_add "app_stats"          "Stats（Menubar 系統監控）"
menu_add "app_pearcleaner"    "Pearcleaner（App 完整移除）"
menu_add "app_monitorcontrol" "MonitorControl（外接螢幕亮度）"
menu_add "app_obsidian"       "Obsidian（知識庫）"

# ── 滑鼠 ──
menu_add "__SECTION__滑鼠" ""
menu_add "app_logitech"   "Logi Options+"

# ── 輸入法 ──
menu_add "__SECTION__輸入法" ""
menu_add "app_rime"       "鼠鬚管（Squirrel）+ 嗯蝦米"

# ── Terminal ──
menu_add "__SECTION__Terminal" ""
menu_add "app_ghostty"    "Ghostty（JetBrains Mono Nerd Font + Solarized Dark）"
menu_add "dev_ohmyzsh"    "Oh My Zsh + Plugins"
menu_add "dev_starship"   "Starship Prompt（Solarized Dark 風格）"
menu_add "dev_vim"        "Vim + vim-plug + Solarized Dark"

# ── 編輯器 ──
menu_add "__SECTION__編輯器" ""
menu_add "app_vscode"     "VS Code + settings.json + 擴充功能"

# ── 開發環境 ──
menu_add "__SECTION__開發環境" ""
menu_add "dev_python"          "pyenv + pyenv-virtualenv（Python 最新穩定版）"
menu_add "dev_node"            "nvm（Node 24 LTS）+ pnpm"
menu_add "dev_git"             "Git 設定 + global .gitignore + SSH config"
menu_add "dev_homebrew_update" "Homebrew 每週自動更新（LaunchAgent）"

menu_run "選擇要安裝的模組（全部預設勾選）"


# ════════════════════════════════════════════════════════════════════
#  區塊 7：確認最終清單
# ════════════════════════════════════════════════════════════════════

clear
echo
echo -e "${BOLD}  安裝清單確認${NC}"
echo
echo -e "  使用者：${BOLD}$USER_DISPLAY_NAME${NC}  電腦名稱：${BOLD}$COMPUTER_NAME${NC}"
if [ "$APPEARANCE" = "light" ]; then
  echo -e "  外觀：淺色"
else
  echo -e "  外觀：深色"
fi
echo
echo -e "  ${BOLD}已勾選模組：${NC}"
for i in "${!MENU_KEYS[@]}"; do
  if [[ "${MENU_KEYS[$i]}" == __SECTION__* ]]; then
    continue
  fi
  if [[ "${MENU_STATE[$i]}" == "1" ]]; then
    echo -e "    ${GREEN}✓${NC} ${MENU_LABELS[$i]}"
  fi
done
echo

read -rp "  確認開始安裝？[y/N] " FINAL_CONFIRM
if [[ ! "$FINAL_CONFIRM" =~ ^[Yy]$ ]]; then
  echo "已取消。"
  exit 0
fi


# ════════════════════════════════════════════════════════════════════
#  區塊 8：系統環境確認
# ════════════════════════════════════════════════════════════════════

section "系統確認"

MACOS_VERSION=$(sw_vers -productVersion)
ARCH=$(uname -m)
info "macOS：$MACOS_VERSION"
info "架構：$ARCH"

if [[ "$ARCH" != "arm64" ]]; then
  warn "此腳本針對 Apple Silicon 設計，目前架構為 $ARCH"
fi
if [[ "$MACOS_VERSION" != 15.* ]] && [[ "$MACOS_VERSION" != 16.* ]]; then
  warn "建議使用 macOS Tahoe (15+)，目前版本 $MACOS_VERSION"
fi

# 設定電腦名稱（只有唯一管理員才執行）
# ComputerName  = Finder / Find My 顯示名稱（可含空格）
# HostName      = 終端機 prompt 顯示的名稱
# LocalHostName = 區域網路 .local 名稱（不可含空格）
if [ -n "$COMPUTER_DISPLAY_NAME" ] && [ -n "$COMPUTER_NETWORK_NAME" ]; then
  sudo scutil --set ComputerName  "$COMPUTER_DISPLAY_NAME"
  sudo scutil --set HostName      "$COMPUTER_NETWORK_NAME"
  sudo scutil --set LocalHostName "$COMPUTER_NETWORK_NAME"
  log "顯示名稱：$COMPUTER_DISPLAY_NAME"
  log "網路名稱：$COMPUTER_NETWORK_NAME"
fi


# ════════════════════════════════════════════════════════════════════
#  區塊 9：Xcode Command Line Tools
#  Homebrew 和 git 都依賴 CLT，必須最先安裝
# ════════════════════════════════════════════════════════════════════

section "Xcode Command Line Tools"

if xcode-select -p &>/dev/null; then
  log "已安裝"
else
  info "安裝 Xcode Command Line Tools..."
  xcode-select --install 2>/dev/null || true
  warn "請在跳出的視窗點擊「安裝」，完成後再回來繼續..."
  warn "若是一行安裝模式（bash <(curl ...)）stdin 被佔用，請改用 bash setup.sh"
  read -r || true
fi


# ════════════════════════════════════════════════════════════════════
#  區塊 10：Homebrew
#
#  Apple Silicon 安裝路徑：/opt/homebrew
#  使用 NONINTERACTIVE=1 避免互動提示卡住一行安裝模式
# ════════════════════════════════════════════════════════════════════

section "Homebrew"

if command -v brew &>/dev/null; then
  log "已安裝，更新中..."
  brew update --quiet || warn "brew update 失敗，繼續執行"
else
  info "安裝 Homebrew（可能需要幾分鐘）..."
  NONINTERACTIVE=1 /bin/bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  # 把 Homebrew 加進 PATH（Apple Silicon 路徑）
  echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$HOME/.zprofile"
  eval "$(/opt/homebrew/bin/brew shellenv)"
  log "Homebrew 安裝完成"
fi


# ════════════════════════════════════════════════════════════════════
#  區塊 11：系統設定（透過 defaults 寫入偏好設定資料庫）
# ════════════════════════════════════════════════════════════════════

section "系統設定"

# ── 外觀模式 ──
if [ "$APPEARANCE" = "dark" ]; then
  osascript -e 'tell application "System Events" to tell appearance preferences to set dark mode to true'
  log "深色模式"
else
  osascript -e 'tell application "System Events" to tell appearance preferences to set dark mode to false'
  log "淺色模式"
fi

# ── 語言：繁中第一、英文第二 ──
if menu_is_on "sys_lang"; then
  defaults write NSGlobalDomain AppleLanguages -array "zh-Hant" "en"
  defaults write NSGlobalDomain AppleLocale -string "zh_TW"
  # zh@collation=stroke：中文按筆畫排序（台灣慣用）
  defaults write NSGlobalDomain AppleCollationOrder -string "zh@collation=stroke"
  log "語言：繁體中文 > 英文"
fi

# ── 按鍵速度 ──
# KeyRepeat=2 是按住時的重複速度（越小越快，最小 1）
# InitialKeyRepeat=25 是按住多久後開始重複（越小延遲越短）
# 此組合等同系統設定中的 75% 快
if menu_is_on "sys_keyrepeat"; then
  defaults write NSGlobalDomain KeyRepeat -int 2
  defaults write NSGlobalDomain InitialKeyRepeat -int 25
  log "按鍵速度（75% 快）"
fi

# ── 關閉自然捲動 ──
# false = 傳統方向（手指向下，畫面向下）
if menu_is_on "sys_scroll"; then
  defaults write NSGlobalDomain com.apple.swipescrolldirection -bool false
  log "自然捲動已關閉"
fi

# ── 觸控板：點一下來選按 ──
# 必須同時設定 BT 和有線觸控板，再加上全域 tapBehavior
if menu_is_on "sys_trackpad"; then
  defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
  defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true
  defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
  defaults write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
  log "觸控板：點一下來選按"
fi

# ── Dock 外觀（圖示順序在套件安裝完後才設定）──
if menu_is_on "sys_dock"; then
  defaults write com.apple.dock orientation             -string "bottom"
  defaults write com.apple.dock autohide                -bool   true
  defaults write com.apple.dock autohide-delay          -float  0      # 移到邊緣立即顯示
  defaults write com.apple.dock autohide-time-modifier  -float  0.3    # 動畫速度
  defaults write com.apple.dock show-recents            -bool   false  # 不顯示最近 App
  defaults write com.apple.dock mineffect               -string "scale" # 縮放比 genie 快
  defaults write com.apple.dock minimize-to-application -bool   false
  log "Dock 外觀完成（圖示稍後設定）"
fi

# ── 螢幕保護 + 睡眠密碼 ──
# idleTime 1200 秒 = 20 分鐘
# askForPasswordDelay 0 = 立即要求密碼
if menu_is_on "sys_screensaver"; then
  defaults write com.apple.screensaver idleTime -int 1200
  defaults -currentHost write com.apple.screensaver idleTime -int 1200
  defaults write com.apple.screensaver askForPassword -int 1
  defaults write com.apple.screensaver askForPasswordDelay -int 0
  log "螢幕保護：20 分鐘 + 立即要求密碼"
fi

# ── 熱角 ──
# 數值對應：2=指揮中心 / 3=應用程式視窗 / 4=桌面 / 5=螢幕保護
# modifier=0 = 不需按住任何修飾鍵
if menu_is_on "sys_hotcorner"; then
  defaults write com.apple.dock wvous-tl-corner -int 5  # 左上：螢幕保護
  defaults write com.apple.dock wvous-tl-modifier -int 0
  defaults write com.apple.dock wvous-tr-corner -int 4  # 右上：桌面
  defaults write com.apple.dock wvous-tr-modifier -int 0
  defaults write com.apple.dock wvous-bl-corner -int 3  # 左下：應用程式視窗
  defaults write com.apple.dock wvous-bl-modifier -int 0
  defaults write com.apple.dock wvous-br-corner -int 2  # 右下：指揮中心
  defaults write com.apple.dock wvous-br-modifier -int 0
  log "熱角設定完成"
fi

# ── 截圖：存到 ~/Desktop/Screenshots，PNG，無陰影 ──
if menu_is_on "sys_screenshot"; then
  SCREENSHOT_DIR="$HOME/Desktop/Screenshots"
  mkdir -p "$SCREENSHOT_DIR"
  defaults write com.apple.screencapture location      "$SCREENSHOT_DIR"
  defaults write com.apple.screencapture type           -string "png"
  defaults write com.apple.screencapture disable-shadow -bool   true
  killall SystemUIServer 2>/dev/null || true
  log "截圖：~/Desktop/Screenshots（無陰影）"
fi

# ── Finder 顯示 ──
if menu_is_on "sys_finder"; then
  defaults write com.apple.finder ShowPathbar              -bool   true
  defaults write com.apple.finder ShowStatusBar            -bool   true
  defaults write NSGlobalDomain   AppleShowAllExtensions   -bool   true
  defaults write com.apple.finder FXPreferredViewStyle     -string "Nlsv"  # List 檢視
  defaults write com.apple.finder FXDefaultSearchScope     -string "SCcf"  # 搜尋當前資料夾
  defaults write com.apple.finder _FXShowPosixPathInTitle  -bool   true
  defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false
  defaults write com.apple.finder ShowRecentTags           -bool   false

  # 新視窗預設開 Home 目錄
  defaults write com.apple.finder NewWindowTarget          -string "PfHm"
  defaults write com.apple.finder NewWindowTargetPath      -string "file://$HOME/"

  killall Finder 2>/dev/null || true
  log "Finder 設定完成"
  add_manual "Finder → 設定 → 側邊欄，手動勾選需要顯示的項目（iCloud Drive、AirDrop、外接硬碟等）"
fi

# ── 選單列：藍芽 + 音量 + 電池（自動偵測有無電池）──
# 電池偵測：用 pmset 看 InternalBattery（比 system_profiler 可靠，不誤判）
if menu_is_on "sys_menubar"; then
  defaults write com.apple.controlcenter "NSStatusItem Visible Bluetooth" -bool true
  defaults write com.apple.controlcenter "NSStatusItem Visible Sound"     -bool true

  if pmset -g batt 2>/dev/null | grep -q "InternalBattery"; then
    defaults write com.apple.controlcenter "NSStatusItem Visible Battery" -bool true
    defaults write com.apple.menuextra.battery ShowPercent -bool true
    log "選單列：藍芽 + 音量 + 電池百分比"
  else
    log "選單列：藍芽 + 音量（無內建電池）"
  fi
  killall SystemUIServer 2>/dev/null || true
fi

# ── 桌面：素色岩石色 ──
# macOS Tahoe 已棄用 desktoppicture.db，改用 osascript 設定
if menu_is_on "sys_wallpaper"; then
  osascript <<'APPLESCRIPT' 2>/dev/null || true
tell application "System Events"
  tell every desktop
    set picture to "/System/Library/Desktop Pictures/Solid Colors/Stone.png"
  end tell
end tell
APPLESCRIPT
  log "桌面：素色岩石色"
  add_manual "若桌面未變更：系統設定 → 桌面與螢幕保護 → 顏色 → 岩石色"
fi

# ── 外接鍵盤 Command ↔ Option 互換 ──
# 透過 hidutil 設定 HID 層按鍵對應，LaunchAgent 確保開機自動套用
#
# HID Usage Code 對照：
#   0x7000000E2 = Left Option   ←→  0x7000000E3 = Left Command
#   0x7000000E6 = Right Option  ←→  0x7000000E7 = Right Command
if menu_is_on "sys_keyboard_remap"; then
  LAUNCH_AGENT_DIR="$HOME/Library/LaunchAgents"
  mkdir -p "$LAUNCH_AGENT_DIR"

  cat >"$LAUNCH_AGENT_DIR/com.user.keyboard-remap.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.user.keyboard-remap</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/bin/hidutil</string>
    <string>property</string>
    <string>--set</string>
    <string>{"UserKeyMapping":[
      {"HIDKeyboardModifierMappingSrc":0x7000000E2,"HIDKeyboardModifierMappingDst":0x7000000E3},
      {"HIDKeyboardModifierMappingSrc":0x7000000E3,"HIDKeyboardModifierMappingDst":0x7000000E2},
      {"HIDKeyboardModifierMappingSrc":0x7000000E6,"HIDKeyboardModifierMappingDst":0x7000000E7},
      {"HIDKeyboardModifierMappingSrc":0x7000000E7,"HIDKeyboardModifierMappingDst":0x7000000E6}
    ]}</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <false/>
</dict>
</plist>
PLIST

  # macOS 13+ 推薦用 bootstrap，舊版用 load
  launchctl bootstrap "gui/$(id -u)" "$LAUNCH_AGENT_DIR/com.user.keyboard-remap.plist" 2>/dev/null \
    || launchctl load "$LAUNCH_AGENT_DIR/com.user.keyboard-remap.plist" 2>/dev/null \
    || true

  log "外接鍵盤 Command ↔ Option 互換（開機自動生效）"
fi

# ── Spotlight 停用，輸入法切換改 Command+Space ──
# AppleSymbolicHotKeys：64=Spotlight, 60=輸入法切換
if menu_is_on "sys_spotlight"; then
  defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 64 \
    '<dict><key>enabled</key><false/><key>value</key><dict><key>parameters</key><array><integer>65535</integer><integer>49</integer><integer>1048576</integer></array><key>type</key><string>standard</string></dict></dict>'
  defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 60 \
    '<dict><key>enabled</key><true/><key>value</key><dict><key>parameters</key><array><integer>32</integer><integer>49</integer><integer>1048576</integer></array><key>type</key><string>standard</string></dict></dict>'
  /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u 2>/dev/null || true
  log "Spotlight 停用，輸入法：Command+Space"
  add_manual "Raycast → Preferences → General → 快捷鍵設為 Option+Space"
fi

# ── 顯示器：關閉鏡象選單列圖示 ──
if menu_is_on "sys_mirror"; then
  defaults write com.apple.airplay showInMenuBarIfPresent -bool false
  log "顯示器：鏡象輸出選項已關閉"
fi

# ── 不在網路/外接磁碟產生 .DS_Store ──
if menu_is_on "sys_ds_store"; then
  defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
  defaults write com.apple.desktopservices DSDontWriteUSBStores     -bool true
  log ".DS_Store 不寫入網路/外接磁碟"
fi

# ── 時區 ──
if menu_is_on "sys_timezone"; then
  sudo systemsetup -settimezone "Asia/Taipei" 2>/dev/null || true
  sudo systemsetup -setusingnetworktime on    2>/dev/null || true
  log "時區：台北，網路自動同步"
fi

# ── macOS 自動更新 ──
if menu_is_on "sys_autoupdate"; then
  sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticCheckEnabled              -bool true
  sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticDownload                  -bool true
  sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticallyInstallMacOSUpdates   -bool true
  sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate CriticalUpdateInstall              -bool true
  sudo defaults write /Library/Preferences/com.apple.commerce       AutoUpdate                         -bool true
  log "macOS 自動更新已開啟"
fi

# ── 防火牆 ──
if menu_is_on "sys_firewall"; then
  sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on
  sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode on
  log "防火牆已開啟（含隱身模式）"
fi

# ── FileVault：全磁碟加密 ──
# 注意：fdesetup 失敗用 || true 避免 pipefail 中止
if menu_is_on "sys_filevault"; then
  FV_STATUS=$(fdesetup status 2>/dev/null || echo "unknown")
  if echo "$FV_STATUS" | grep -q "FileVault is On"; then
    log "FileVault 已開啟"
  else
    info "開啟 FileVault..."
    sudo fdesetup enable -user "$(whoami)" || warn "FileVault 開啟失敗，請手動開啟"
    echo
    echo -e "${BOLD}${RED}  ══════════════════════════════════════════${NC}"
    echo -e "${BOLD}${RED}  ⚠  FileVault Recovery Key 已顯示如上${NC}"
    echo -e "${BOLD}${RED}  ⚠  請立即複製並存入 1Password！${NC}"
    echo -e "${BOLD}${RED}  ══════════════════════════════════════════${NC}"
    echo
    read -rp "  已存入 1Password？[y/N] " FV_CONFIRM
    log "FileVault 已開啟"
  fi
  add_manual "確認 FileVault Recovery Key 已存入 1Password"
fi


# ════════════════════════════════════════════════════════════════════
#  區塊 12：套件安裝
# ════════════════════════════════════════════════════════════════════

section "安裝套件"

if menu_is_on "app_chrome";        then brew_cask "google-chrome";    fi
if menu_is_on "app_brave";         then brew_cask "brave-browser";    fi
if menu_is_on "app_1password"; then
  brew_cask "1password"
  brew_cask "1password-cli"   # op 指令，Oh My Zsh 1password plugin 和終端機整合需要
fi
if menu_is_on "app_spotify";       then brew_cask "spotify";          fi
if menu_is_on "app_rectangle";     then brew_cask "rectangle";        fi
if menu_is_on "app_raycast";       then brew_cask "raycast";          fi
if menu_is_on "app_stats";         then brew_cask "stats";            fi
if menu_is_on "app_pearcleaner";   then brew_cask "pearcleaner";      fi
if menu_is_on "app_monitorcontrol";then brew_cask "monitorcontrol";   fi
if menu_is_on "app_obsidian";      then brew_cask "obsidian";         fi
if menu_is_on "app_logitech";      then brew_cask "logi-options+";    fi
if menu_is_on "app_vscode";        then brew_cask "visual-studio-code"; fi

if menu_is_on "app_ghostty"; then
  brew_cask "ghostty"
  # Nerd Font 已在 Homebrew 主 tap，不需要 homebrew/cask-fonts（已棄用）
  brew_cask "font-jetbrains-mono-nerd-font"
fi


# ════════════════════════════════════════════════════════════════════
#  區塊 13：Dock 圖示順序（必須在套件安裝後執行）
#
#  Dock 順序：Finder · Safari · Chrome · Brave · Spotify
#             Ghostty · VS Code · Obsidian · 系統設定
# ════════════════════════════════════════════════════════════════════

if menu_is_on "sys_dock"; then
  # 清空 Dock，重新排列
  defaults write com.apple.dock persistent-apps -array

  add_dock_app "/System/Library/CoreServices/Finder.app"
  add_dock_app "/Applications/Safari.app"
  add_dock_app "/Applications/Google Chrome.app"
  add_dock_app "/Applications/Brave Browser.app"
  add_dock_app "/Applications/Spotify.app"
  add_dock_app "/Applications/Ghostty.app"
  add_dock_app "/Applications/Visual Studio Code.app"
  add_dock_app "/Applications/Obsidian.app"
  # Ventura+ 是 System Settings，舊版是 System Preferences
  add_dock_app "/System/Applications/System Settings.app"
  add_dock_app "/System/Applications/System Preferences.app"

  killall Dock 2>/dev/null || true
  log "Dock 圖示設定完成"
fi


# ════════════════════════════════════════════════════════════════════
#  區塊 14：輸入法（鼠鬚管 + 嗯蝦米）
#
#  鼠鬚管 = Rime 輸入法的 macOS 版本
#  嗯蝦米 = 倚天/無蝦米的開源相容方案（liur）
# ════════════════════════════════════════════════════════════════════

section "輸入法"

if menu_is_on "app_rime"; then
  brew_cask "squirrel"
  RIME_DIR="$HOME/Library/Rime"
  mkdir -p "$RIME_DIR"

  # 嗯蝦米方案不存在才安裝（避免覆蓋現有設定）
  if [ -f "$RIME_DIR/liur.schema.yaml" ]; then
    log "嗯蝦米已存在"
  else
    info "安裝嗯蝦米..."
    if curl -fsSL https://git.io/rime_liur_installer | bash; then
      log "嗯蝦米完成"
    else
      warn "嗯蝦米自動安裝失敗"
      add_manual "手動執行：curl -fsSL https://git.io/rime_liur_installer | bash"
    fi
  fi

  # 設定預設輸入方案為嗯蝦米，切換熱鍵 Ctrl+`
  cat >"$RIME_DIR/default.custom.yaml" <<'RIME'
patch:
  schema_list:
    - schema: liur
  switcher/hotkeys:
    - "Control+grave"
RIME

  log "鼠鬚管設定完成"
  add_manual "系統設定 → 鍵盤 → 輸入來源 → 新增「鼠鬚管」"
  add_manual "選單列鼠鬚管圖示 → 重新部署（讓嗯蝦米方案生效）"
fi


# ════════════════════════════════════════════════════════════════════
#  區塊 15：Ghostty 設定
# ════════════════════════════════════════════════════════════════════

section "Ghostty"

if menu_is_on "app_ghostty"; then
  mkdir -p "$HOME/.config/ghostty"
  cat >"$HOME/.config/ghostty/config" <<'GHOSTTY'
# ── 外觀 ───────────────────────────────────────────
theme              = "Solarized Dark"
font-family        = "JetBrains Mono Nerd Font"
font-size          = 14
window-padding-x   = 12
window-padding-y   = 10

# ── 游標 ───────────────────────────────────────────
cursor-style       = bar
cursor-style-blink = true

# ── 效能 ───────────────────────────────────────────
scrollback-limit   = 10000

# ── 視窗 ───────────────────────────────────────────
window-decoration    = true
macos-titlebar-style = hidden
GHOSTTY
  log "Ghostty 設定完成"
fi


# ════════════════════════════════════════════════════════════════════
#  區塊 16：Oh My Zsh + Plugins
#
#  注意事項：
#  - ZSH_THEME=""：由 Starship 接手 prompt，不用 OMZ theme
#  - 移除 1password plugin（需要 op CLI，未裝）
#  - NVM_DIR 必須在 source omz 之前 export，否則 nvm plugin 載入失敗
# ════════════════════════════════════════════════════════════════════

section "Oh My Zsh"

if menu_is_on "dev_ohmyzsh"; then
  # 安裝 Oh My Zsh 本體
  if [ -d "$HOME/.oh-my-zsh" ]; then
    log "Oh My Zsh 已安裝"
  else
    info "安裝 Oh My Zsh..."
    if RUNZSH=no CHSH=no sh -c \
        "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"; then
      log "Oh My Zsh ✓"
    else
      warn "Oh My Zsh 安裝失敗"
    fi
  fi

  # 安裝第三方 plugin（先檢查再 clone，避免重複）
  ZSH_CUSTOM_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

  zsh_plugin() {
    local plugin_name=$1 repo=$2
    if [ -d "$ZSH_CUSTOM_DIR/plugins/$plugin_name" ]; then
      log "$plugin_name 已安裝"
      return 0
    fi
    info "安裝 $plugin_name..."
    if git clone --depth=1 "https://github.com/$repo" "$ZSH_CUSTOM_DIR/plugins/$plugin_name" &>/dev/null; then
      log "$plugin_name ✓"
    else
      warn "$plugin_name 安裝失敗"
    fi
    return 0
  }

  zsh_plugin "zsh-autosuggestions"     "zsh-users/zsh-autosuggestions"
  zsh_plugin "zsh-syntax-highlighting" "zsh-users/zsh-syntax-highlighting"
  zsh_plugin "zsh-autocomplete"        "marlonrichert/zsh-autocomplete"
  zsh_plugin "you-should-use"          "MichaelAquilina/zsh-you-should-use"

  # 寫入 .zshrc（用單引號 heredoc，內容不展開變數）
  cat >"$HOME/.zshrc" <<'ZSHRC'
# ════════════════════════════════════════════════════
#  .zshrc — 由 setup.sh 自動產生
# ════════════════════════════════════════════════════

# ── nvm 環境（必須在 source omz 之前 export，
#    否則 omz 的 nvm plugin 載入時找不到 nvm）─────────
export NVM_DIR="$HOME/.nvm"

# ── Oh My Zsh ──────────────────────────────────────
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME=""                       # 由 Starship 負責 prompt
DISABLE_AUTO_UPDATE="true"
DISABLE_MAGIC_FUNCTIONS="true"

# 注意：1password plugin 需要 op CLI，已隨 1password-cli 一起安裝
plugins=(
  git
  macos
  history
  colored-man-pages
  1password
  nvm
  zsh-autosuggestions
  zsh-syntax-highlighting
  you-should-use
  zsh-autocomplete
)

source $ZSH/oh-my-zsh.sh

# ── Homebrew ───────────────────────────────────────
eval "$(/opt/homebrew/bin/brew shellenv)"

# ── Starship Prompt ────────────────────────────────
if command -v starship &>/dev/null; then
  eval "$(starship init zsh)"
fi

# ── pyenv ──────────────────────────────────────────
# 先設好 PATH，再用 PATH 找 pyenv
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
if command -v pyenv &>/dev/null; then
  eval "$(pyenv init --path)"
  eval "$(pyenv init -)"
  eval "$(pyenv virtualenv-init -)"
fi

# ── nvm 載入 ───────────────────────────────────────
[ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && \. "/opt/homebrew/opt/nvm/nvm.sh"
[ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ] && \
  \. "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"

# ── 1Password SSH Agent ────────────────────────────
# 所有 SSH 連線（含 git）透過 1Password 驗證
export SSH_AUTH_SOCK="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"

# ── 語言環境 ───────────────────────────────────────
export LANG=zh_TW.UTF-8
export LC_ALL=zh_TW.UTF-8
export LC_CTYPE=zh_TW.UTF-8

# ── Editor ─────────────────────────────────────────
export GIT_EDITOR=vim
export EDITOR=vim
export VISUAL=vim

# ── Aliases ────────────────────────────────────────
alias ll='ls -lah'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias reload='source ~/.zshrc'
alias zshconfig='vim ~/.zshrc'
alias vimconfig='vim ~/.vimrc'
alias grep='grep --color=auto'
alias df='df -h'
alias du='du -h'
alias ports='lsof -iTCP -sTCP:LISTEN -P'
alias myip='curl -s https://api.ipify.org'

# ── Git Aliases ────────────────────────────────────
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git pull'
alias glog='git log --oneline --graph --decorate'
alias gd='git diff'
alias gb='git branch'
alias gco='git checkout'

# ── ZSH 補全外觀 ───────────────────────────────────
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#6c7a89"
ZSH_AUTOSUGGEST_USE_ASYNC=1
ZSHRC

  log ".zshrc 完成"
fi


# ════════════════════════════════════════════════════════════════════
#  區塊 17：Starship Prompt
#
#  跨 shell 現代 prompt，顯示目錄、git 狀態、Python/Node 版本
#  色彩風格：Solarized Dark（與 Ghostty 和 Vim 統一）
# ════════════════════════════════════════════════════════════════════

section "Starship"

if menu_is_on "dev_starship"; then
  brew_pkg "starship"
  mkdir -p "$HOME/.config"
  cat >"$HOME/.config/starship.toml" <<'STARSHIP'
# Starship · Solarized Dark 風格
format = """
$username\
$hostname\
$directory\
$git_branch\
$git_status\
$python\
$nodejs\
$line_break\
$character"""

[character]
success_symbol = "[❯](bold green)"
error_symbol   = "[❯](bold red)"

[directory]
style             = "bold cyan"
truncation_length = 3
truncate_to_repo  = true
read_only         = " 🔒"

[git_branch]
symbol = " "
style  = "bold yellow"
format = "[$symbol$branch]($style) "

[git_status]
style     = "bold red"
ahead     = "⇡${count}"
behind    = "⇣${count}"
diverged  = "⇕⇡${ahead_count}⇣${behind_count}"
modified  = "!${count}"
untracked = "?${count}"
staged    = "+${count}"
deleted   = "✘${count}"

[python]
symbol = " "
style  = "bold blue"
format = "[$symbol$version]($style) "

[nodejs]
symbol = " "
style  = "bold green"
format = "[$symbol$version]($style) "

[username]
show_always = false

[hostname]
ssh_only = true
style    = "bold yellow"
STARSHIP

  log "Starship 完成"
fi


# ════════════════════════════════════════════════════════════════════
#  區塊 18：Vim 設定
#
#  vim-plug + 10 個常用 plugin，Solarized Dark 主題
#  注意：colorscheme 用 silent! 避免首次啟動時 plugin 還沒下載前報錯
# ════════════════════════════════════════════════════════════════════

section "Vim"

if menu_is_on "dev_vim"; then
  brew_pkg "vim"

  # 安裝 vim-plug
  if [ -f "$HOME/.vim/autoload/plug.vim" ]; then
    log "vim-plug 已安裝"
  else
    info "安裝 vim-plug..."
    if curl -fLo "$HOME/.vim/autoload/plug.vim" --create-dirs \
        https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim 2>/dev/null; then
      log "vim-plug ✓"
    else
      warn "vim-plug 安裝失敗"
      add_manual "手動安裝 vim-plug：https://github.com/junegunn/vim-plug"
    fi
  fi

  cat >"$HOME/.vimrc" <<'VIMRC'
" ── vim-plug ───────────────────────────────────────
call plug#begin('~/.vim/plugged')
  Plug 'altercation/vim-colors-solarized'   " 主題
  Plug 'vim-airline/vim-airline'             " 狀態列
  Plug 'vim-airline/vim-airline-themes'      " 狀態列主題
  Plug 'preservim/nerdtree'                  " 檔案樹（Ctrl-N）
  Plug 'airblade/vim-gitgutter'              " Git 行狀態
  Plug 'tpope/vim-fugitive'                  " :Git 指令整合
  Plug 'dense-analysis/ale'                  " 非同步語法檢查
  Plug 'Yggdroot/indentLine'                 " 縮排線
  Plug 'tpope/vim-commentary'                " gc 註解
  Plug 'jiangmiao/auto-pairs'                " 括號自動配對
call plug#end()

" ── 外觀（silent! 避免首次啟動 plugin 未下載報錯）─
syntax enable
set background=dark
silent! colorscheme solarized
let g:airline_theme='solarized'
let g:airline_powerline_fonts=1
let g:airline#extensions#tabline#enabled=1

" ── 行號 ───────────────────────────────────────────
set number
set relativenumber
set cursorline

" ── UI ────────────────────────────────────────────
set showcmd
set showmatch
set wildmenu
set wildmode=list:longest
set laststatus=2
set scrolloff=8
set sidescrolloff=8

" ── 搜尋 ───────────────────────────────────────────
set incsearch
set hlsearch
set ignorecase
set smartcase

" ── 縮排 ───────────────────────────────────────────
set expandtab
set shiftwidth=2
set tabstop=2
set smartindent
set autoindent

" ── 檔案 ───────────────────────────────────────────
set encoding=utf-8
set fileencoding=utf-8
set fileencodings=utf-8,big5,gbk,latin1
set autoread
set noswapfile
set nobackup
set nowritebackup
set hidden

" ── 滑鼠 ───────────────────────────────────────────
set mouse=a

" ── 語法縮排規則 ───────────────────────────────────
filetype plugin indent on
autocmd BufNewFile,BufRead *.py     set tabstop=4 shiftwidth=4
autocmd BufNewFile,BufRead *.yaml,*.yml setlocal tabstop=2 shiftwidth=2
autocmd BufNewFile,BufRead *.json   setlocal tabstop=2 shiftwidth=2
autocmd BufNewFile,BufRead *.md     setlocal tabstop=2 shiftwidth=2 wrap linebreak

" ── NERDTree ──────────────────────────────────────
map <C-n> :NERDTreeToggle<CR>
let NERDTreeShowHidden=1
let NERDTreeMinimalUI=1
let NERDTreeIgnore=['\.DS_Store$', '\.git$', '__pycache__']

" ── ALE 語法檢查 ───────────────────────────────────
let g:ale_linters = {'python': ['flake8'], 'yaml': ['yamllint']}
let g:ale_fixers  = {'python': ['autopep8'], '*': ['remove_trailing_lines', 'trim_whitespace']}
let g:ale_fix_on_save=1

" ── 快捷鍵 ─────────────────────────────────────────
let mapleader=","
nnoremap <leader>w :w<CR>
nnoremap <leader>q :q<CR>
nnoremap <leader>x :x<CR>
nnoremap <esc> :noh<return><esc>
nnoremap <leader>] :bnext<CR>
nnoremap <leader>[ :bprevious<CR>
nnoremap <leader>v :vsplit<CR>
nnoremap <leader>s :split<CR>
nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l
vnoremap <leader>y "+y
nnoremap <leader>p "+p
VIMRC

  # 自動執行 :PlugInstall
  if vim +PlugInstall +qall &>/dev/null; then
    log "Vim plugins 完成"
  else
    warn "Vim plugins 自動安裝失敗"
    add_manual "開啟 Vim → 執行 :PlugInstall"
  fi
fi


# ════════════════════════════════════════════════════════════════════
#  區塊 19：VS Code 設定
# ════════════════════════════════════════════════════════════════════

section "VS Code"

if menu_is_on "app_vscode"; then
  # 安裝擴充功能
  if command -v code &>/dev/null; then
    for ext in \
      "ms-python.python" \
      "eamodio.gitlens" \
      "redhat.vscode-yaml" \
      "vscodevim.vim" \
      "1Password.op-vscode" \
      "esbenp.prettier-vscode"
    do
      if code --install-extension "$ext" --force &>/dev/null; then
        log "$ext ✓"
      else
        warn "$ext 安裝失敗"
      fi
    done
  else
    warn "VS Code CLI（code 指令）未找到"
    add_manual "VS Code → Command Palette → 'Shell Command: Install code in PATH'，再重新執行腳本"
  fi

  # settings.json（路徑含空白，必須用雙引號）
  VSCODE_SETTINGS_DIR="$HOME/Library/Application Support/Code/User"
  mkdir -p "$VSCODE_SETTINGS_DIR"
  cat >"$VSCODE_SETTINGS_DIR/settings.json" <<'VSCODE'
{
  "workbench.colorTheme": "Solarized Dark",
  "editor.fontFamily": "'JetBrains Mono', 'JetBrains Mono Nerd Font', monospace",
  "editor.fontSize": 14,
  "editor.lineHeight": 1.6,
  "editor.fontLigatures": true,
  "editor.renderWhitespace": "boundary",
  "editor.rulers": [80, 120],
  "workbench.tree.indent": 16,
  "editor.tabSize": 2,
  "editor.insertSpaces": true,
  "editor.detectIndentation": true,
  "editor.formatOnSave": true,
  "editor.formatOnPaste": false,
  "editor.wordWrap": "off",
  "editor.minimap.enabled": false,
  "editor.cursorBlinking": "smooth",
  "editor.cursorSmoothCaretAnimation": "on",
  "editor.smoothScrolling": true,
  "editor.bracketPairColorization.enabled": true,
  "editor.guides.bracketPairs": true,
  "vim.enable": true,
  "vim.leader": ",",
  "vim.hlsearch": true,
  "vim.useSystemClipboard": true,
  "vim.normalModeKeyBindingsNonRecursive": [
    { "before": ["<esc>"], "commands": [":nohl"] },
    { "before": ["<leader>", "w"], "commands": [":w"] },
    { "before": ["<leader>", "q"], "commands": [":q"] }
  ],
  "files.trimTrailingWhitespace": true,
  "files.insertFinalNewline": true,
  "files.encoding": "utf8",
  "files.autoSave": "onFocusChange",
  "files.exclude": {
    "**/.DS_Store": true,
    "**/__pycache__": true,
    "**/.pytest_cache": true,
    "**/node_modules": true
  },
  "terminal.integrated.fontFamily": "'JetBrains Mono Nerd Font'",
  "terminal.integrated.fontSize": 13,
  "terminal.integrated.defaultProfile.osx": "zsh",
  "git.autofetch": true,
  "git.confirmSync": false,
  "git.enableSmartCommit": true,
  "gitlens.codeLens.enabled": false,
  "python.defaultInterpreterPath": "~/.pyenv/shims/python",
  "[python]": {
    "editor.tabSize": 4,
    "editor.defaultFormatter": "ms-python.python"
  },
  "[yaml]": {
    "editor.tabSize": 2,
    "editor.defaultFormatter": "esbenp.prettier-vscode"
  },
  "breadcrumbs.enabled": true,
  "explorer.confirmDelete": false,
  "explorer.confirmDragAndDrop": false,
  "security.workspace.trust.enabled": false,
  "telemetry.telemetryLevel": "off",
  "update.mode": "manual",
  "extensions.autoUpdate": false
}
VSCODE
  log "VS Code settings.json 完成"
fi


# ════════════════════════════════════════════════════════════════════
#  區塊 20：開發環境
# ════════════════════════════════════════════════════════════════════

section "開發環境"

# ── Python：pyenv + pyenv-virtualenv ──
if menu_is_on "dev_python"; then
  brew_pkg "pyenv"
  brew_pkg "pyenv-virtualenv"

  export PYENV_ROOT="$HOME/.pyenv"
  export PATH="$PYENV_ROOT/bin:$PATH"
  eval "$(pyenv init --path)" 2>/dev/null || true

  if ! command -v pyenv &>/dev/null; then
    warn "pyenv 不可用，跳過 Python 版本安裝"
    add_manual "新終端機執行：pyenv install <version> && pyenv global <version>"
  else
    # 取最新 3.x.x 穩定版（過濾 alpha/beta/dev）
    # 注意：用 || true 保護整個 pipeline，避免 grep 沒匹配導致中止
    LATEST_PYTHON=$(pyenv install --list 2>/dev/null \
      | grep -E "^\s+3\.[0-9]+\.[0-9]+$" \
      | tail -1 \
      | tr -d ' ' \
      || true)

    if [ -z "$LATEST_PYTHON" ]; then
      warn "找不到 Python 最新穩定版"
      add_manual "新終端機執行：pyenv install --list 找版本後安裝"
    else
      info "Python 最新穩定版：$LATEST_PYTHON"
      if pyenv versions 2>/dev/null | grep -q "$LATEST_PYTHON"; then
        log "Python $LATEST_PYTHON 已安裝"
      else
        info "安裝 Python $LATEST_PYTHON（需幾分鐘）..."
        if pyenv install "$LATEST_PYTHON"; then
          log "Python $LATEST_PYTHON ✓"
        else
          warn "Python 安裝失敗"
        fi
      fi
      pyenv global "$LATEST_PYTHON" 2>/dev/null || true
      log "Python 設定完成"
    fi
  fi
fi

# ── Node：nvm + Node 24 LTS + pnpm ──
if menu_is_on "dev_node"; then
  brew_pkg "nvm"

  export NVM_DIR="$HOME/.nvm"
  mkdir -p "$NVM_DIR"

  if [ ! -s "/opt/homebrew/opt/nvm/nvm.sh" ]; then
    warn "nvm.sh 找不到，無法立即安裝 Node"
    add_manual "新終端機執行：nvm install 24 && nvm alias default 24 && npm install -g pnpm"
  else
    \. "/opt/homebrew/opt/nvm/nvm.sh"
    if nvm install 24; then
      nvm alias default 24
      nvm use 24
      echo "24" >"$HOME/.nvmrc"
      if npm install -g pnpm; then
        log "Node 24 LTS + pnpm 完成"
      else
        warn "pnpm 安裝失敗"
      fi
    else
      warn "Node 24 安裝失敗"
    fi
  fi
fi

# ── Git 設定 + SSH config + 全域 .gitignore ──
if menu_is_on "dev_git"; then
  # Git 基本設定
  if [ -n "$GIT_NAME" ];  then git config --global user.name  "$GIT_NAME";  fi
  if [ -n "$GIT_EMAIL" ]; then git config --global user.email "$GIT_EMAIL"; fi

  git config --global core.editor          "vim"
  git config --global init.defaultBranch   "main"
  git config --global pull.rebase          false
  git config --global core.autocrlf        input    # 提交時轉 LF，checkout 保持
  git config --global core.precomposeunicode true   # macOS 中文檔名正規化
  git config --global fetch.prune          true     # fetch 時清除已消失的遠端分支
  git config --global diff.colorMoved      zebra    # 移動的行用不同色
  git config --global merge.conflictstyle  diff3    # 衝突顯示三方
  git config --global rebase.autoStash     true     # rebase 前自動 stash

  # 1Password SSH 簽名（需要時手動開啟 commit.gpgsign）
  git config --global gpg.format           ssh
  git config --global gpg.ssh.program      "/Applications/1Password.app/Contents/MacOS/op-ssh-sign"
  git config --global commit.gpgsign       false

  # SSH config（用無引號 heredoc 讓 $HOME 展開為實際路徑）
  # 重要：IdentityAgent 不能用 ~（SSH 不展開 ~）
  # 重要：SSH config 不支援行內 # 註解，必須獨立行
  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"
  cat >"$HOME/.ssh/config" <<SSH_CONFIG
# ── GitHub ─────────────────────────────────────
Host github.com
  HostName github.com
  User git
  IdentityAgent "$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"

# ── 全域預設 ───────────────────────────────────
# ServerAliveInterval：每 60 秒 keepalive
# ServerAliveCountMax：最多重試 3 次
# AddKeysToAgent：自動將私鑰加入 agent
Host *
  ServerAliveInterval 60
  ServerAliveCountMax 3
  AddKeysToAgent yes
SSH_CONFIG
  chmod 600 "$HOME/.ssh/config"
  log "SSH config 完成"

  # 全域 .gitignore
  cat >"$HOME/.gitignore_global" <<'GITIGNORE'
# ── macOS ──────────────────────────────────────
.DS_Store
.DS_Store?
._*
.Spotlight-V100
.Trashes
.AppleDouble
.LSOverride

# ── 編輯器 ──────────────────────────────────────
.vscode/
*.swp
*.swo
*~
.idea/
*.iml

# ── Python ──────────────────────────────────────
__pycache__/
*.py[cod]
*$py.class
*.pyc
.Python
.pyenv/
.venv/
venv/
env/
*.egg-info/
dist/
build/
.pytest_cache/
.coverage
htmlcov/

# ── Node ────────────────────────────────────────
node_modules/
npm-debug.log*
yarn-debug.log*
yarn-error.log*
.pnpm-debug.log*
.npm
.node_repl_history

# ── 環境變數（不能進版本控制）─────────────────────
.env
.env.local
.env.*.local
*.env

# ── 日誌 ────────────────────────────────────────
*.log
logs/

# ── Windows 殘留檔 ──────────────────────────────
Thumbs.db
ehthumbs.db
Desktop.ini
GITIGNORE

  git config --global core.excludesfile "$HOME/.gitignore_global"
  log "全域 .gitignore 完成"

  if [ -n "$GIT_NAME" ]; then
    log "Git 完成（$GIT_NAME / $GIT_EMAIL）"
  fi

  add_manual "1Password → 設定 → Developer → 開啟 SSH Agent"
  add_manual "1Password 建立 SSH Key（Ed25519）→ 加入 GitHub"
  add_manual "測試連線：ssh -T git@github.com"
fi

# ── Homebrew 自動更新（每週日凌晨 3:00）──
if menu_is_on "dev_homebrew_update"; then
  LAUNCH_AGENT_DIR="$HOME/Library/LaunchAgents"
  mkdir -p "$LAUNCH_AGENT_DIR"

  # plist 內 && 必須寫 &amp;&amp;（XML 跳脫）
  cat >"$LAUNCH_AGENT_DIR/com.user.brew-update.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.user.brew-update</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>-c</string>
    <string>eval "$(/opt/homebrew/bin/brew shellenv)" &amp;&amp; brew update &amp;&amp; brew upgrade &amp;&amp; brew cleanup</string>
  </array>
  <key>StartCalendarInterval</key>
  <dict>
    <key>Weekday</key>
    <integer>0</integer>
    <key>Hour</key>
    <integer>3</integer>
    <key>Minute</key>
    <integer>0</integer>
  </dict>
  <key>StandardOutPath</key>
  <string>/tmp/brew-update.log</string>
  <key>StandardErrorPath</key>
  <string>/tmp/brew-update.log</string>
</dict>
</plist>
PLIST

  # 優先用 bootstrap（macOS 13+），失敗退回 load
  launchctl bootstrap "gui/$(id -u)" "$LAUNCH_AGENT_DIR/com.user.brew-update.plist" 2>/dev/null \
    || launchctl load "$LAUNCH_AGENT_DIR/com.user.brew-update.plist" 2>/dev/null \
    || true

  log "Homebrew 每週日凌晨 3:00 自動更新"
fi


# ════════════════════════════════════════════════════════════════════
#  區塊 21：確保所有套件都是最新版
# ════════════════════════════════════════════════════════════════════

section "更新所有套件"
info "執行 brew upgrade（確保所有 CLI 工具和 App 都是最新版）..."
brew upgrade 2>&1 | grep -v "^$" || true
brew upgrade --cask 2>&1 | grep -v "^$" || true
brew cleanup
log "所有套件已更新"




# 檢查瀏覽器 + 1Password 組合，提醒安裝瀏覽器擴充
HAS_CHROME=false
HAS_BRAVE=false
HAS_1PW=false
if menu_is_on "app_chrome";    then HAS_CHROME=true; fi
if menu_is_on "app_brave";     then HAS_BRAVE=true;  fi
if menu_is_on "app_1password"; then HAS_1PW=true;    fi

if [ "$HAS_1PW" = "true" ]; then
  if [ "$HAS_CHROME" = "true" ]; then
    add_manual "Chrome：安裝 1Password 擴充功能"
  fi
  if [ "$HAS_BRAVE" = "true" ]; then
    add_manual "Brave：安裝 1Password 擴充功能"
  fi
fi

if menu_is_on "app_logitech"; then
  add_manual "Logi Options+：將 Lift Left 主按鍵對調為右手佈局"
fi

add_manual "Safari → File → Add to Dock → calendar.google.com（Google Calendar）"


# ════════════════════════════════════════════════════════════════════
#  區塊 23：套用所有系統設定
# ════════════════════════════════════════════════════════════════════

section "套用設定"

killall Finder SystemUIServer Dock 2>/dev/null || true
/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u 2>/dev/null || true
log "系統設定已套用"


# ════════════════════════════════════════════════════════════════════
#  區塊 24：完成畫面
# ════════════════════════════════════════════════════════════════════

clear
echo
echo -e "${BOLD}${GREEN}"
echo "  ╔══════════════════════════════════════════╗"
echo "  ║          ✅  安裝完成！                  ║"
echo "  ╚══════════════════════════════════════════╝"
echo -e "${NC}"
echo -e "  使用者:    ${BOLD}$USER_DISPLAY_NAME${NC}"
if [ -n "$COMPUTER_DISPLAY_NAME" ]; then
  echo -e "  顯示名稱:  ${BOLD}$COMPUTER_DISPLAY_NAME${NC}"
  echo -e "  網路名稱:  ${BOLD}$COMPUTER_NETWORK_NAME${NC}"
fi
if [ "$APPEARANCE" = "light" ]; then
  echo -e "  外觀:      淺色"
else
  echo -e "  外觀:      深色"
fi

if [ ${#MANUAL_STEPS[@]} -gt 0 ]; then
  echo
  echo -e "${BOLD}${YELLOW}  需要手動完成的步驟：${NC}"
  echo
  for i in "${!MANUAL_STEPS[@]}"; do
    echo -e "  ${YELLOW}$((i + 1)).${NC} ${MANUAL_STEPS[$i]}"
  done
fi

echo
echo -e "${BOLD}  ▶ 建議重新啟動電腦以套用所有設定${NC}"
echo
