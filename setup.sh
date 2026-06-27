#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════════
#  macOS Setup Script
#  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  新帳號開好後執行，一次完成系統設定、軟體安裝和開發環境建置
#
#  支援：macOS Tahoe (26+) · Apple Silicon (M 系列)
#
#  執行方式（推薦本機，互動更穩定）：
#    bash setup.sh
#
#  一行安裝（從 GitHub 直接執行）：
#    bash <(curl -fsSL https://raw.githubusercontent.com/YOUR_USER/mac-setup/main/setup.sh)
#
#  注意：腳本不含任何個人資訊，所有私人資料在執行時輸入
# ════════════════════════════════════════════════════════════════════

set -euo pipefail

# ── stdin 修正（bash <(curl ...) 模式下 stdin 被管道佔用）──────────
# 在任何 read 之前把 stdin 重導向到終端機，讓互動式輸入正常運作。
# 注意：/dev/tty 存在但無控制終端時 exec 會失敗（ENXIO），故加 || true 不讓 set -e 中止。
if [[ ! -t 0 ]] && [[ -e /dev/tty ]]; then
  exec </dev/tty 2>/dev/null || true
fi

# 本腳本全程需要互動輸入；若仍無可用終端機（CI / cron / 無 tty 容器）就明確中止，
# 而非在第一個 read 時無訊息退出
if [[ ! -t 0 ]]; then
  echo "錯誤：此腳本需要互動式終端機，請用「bash setup.sh」在終端機中執行" >&2
  exit 1
fi


# ════════════════════════════════════════════════════════════════════
#  區塊 1：終端機輸出工具
# ════════════════════════════════════════════════════════════════════

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

MANUAL_STEPS=()
add_manual() { MANUAL_STEPS+=("$1"); }

# ── 備份輔助：覆蓋設定檔前先建立時間戳備份 ──────────────────────────
backup_if_exists() {
  local file=$1
  if [[ -f "$file" ]] && [[ -s "$file" ]]; then
    local backup="${file}.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$file" "$backup"
    warn "已備份 $(basename "$file") → $backup"
  fi
}


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

menu_add() {
  local key=$1 label=$2 state=${3:-1}
  MENU_KEYS+=("$key")
  MENU_LABELS+=("$label")
  MENU_STATE+=("$state")
}

menu_is_on() {
  local target=$1 i
  for i in "${!MENU_KEYS[@]}"; do
    if [[ "${MENU_KEYS[$i]}" == "$target" ]] && [[ "${MENU_STATE[$i]}" == "1" ]]; then
      return 0
    fi
  done
  return 1
}

menu_run() {
  local title=$1
  local display_num count key label state num i input

  while true; do
    clear
    echo
    echo -e "${BOLD}${CYAN}  $title${NC}"
    echo -e "  ${DIM}數字鍵切換勾選 · 空格分隔多選（例：1 3 5）· A=全選 · N=全不選 · Enter=確認${NC}"
    echo

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
        for i in "${!MENU_KEYS[@]}"; do
          if [[ "${MENU_KEYS[$i]}" != __SECTION__* ]]; then
            MENU_STATE[$i]=1
          fi
        done
        ;;
      [Nn])
        for i in "${!MENU_KEYS[@]}"; do
          if [[ "${MENU_KEYS[$i]}" != __SECTION__* ]]; then
            MENU_STATE[$i]=0
          fi
        done
        ;;
      *)
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
#  使用 python3 plistlib 直接操作 binary plist，確保資料型別正確
#  （defaults write -array-add 傳入 XML 字串會將 dict 存成 String 型別，
#  導致 Dock 讀取設定失敗；plistlib 寫入的型別與 Dock 期望的完全一致）
#
#  同時解決路徑含 & 字元的 XML 跳脫問題
# ════════════════════════════════════════════════════════════════════

add_dock_app() {
  local app_path=$1
  [[ -e "$app_path" ]] || return 0
  python3 - "$app_path" <<'PYTHON'
import sys, plistlib
from pathlib import Path

plist = Path.home() / "Library/Preferences/com.apple.dock.plist"
app  = sys.argv[1]
name = app.rsplit("/", 1)[-1].removesuffix(".app")

with open(plist, "rb") as f:
    data = plistlib.load(f)

entry = {
    "tile-type": "file-tile",
    "tile-data": {
        "file-data": {
            "_CFURLString": app,
            "_CFURLStringType": 0,
        },
        "file-label": name,
        "file-type": 32,
    },
}
data.setdefault("persistent-apps", []).append(entry)

with open(plist, "wb") as f:
    plistlib.dump(data, f, fmt=plistlib.FMT_BINARY)
PYTHON
}

# Dock 清空（在套件安裝後重新排列前呼叫）
dock_reset() {
  python3 - <<'PYTHON'
import plistlib
from pathlib import Path

plist = Path.home() / "Library/Preferences/com.apple.dock.plist"
with open(plist, "rb") as f:
    data = plistlib.load(f)
data["persistent-apps"] = []
with open(plist, "wb") as f:
    plistlib.dump(data, f, fmt=plistlib.FMT_BINARY)
PYTHON
}


# ════════════════════════════════════════════════════════════════════
#  區塊 5：歡迎畫面 + 基本資訊輸入
# ════════════════════════════════════════════════════════════════════

clear
echo
echo -e "${BOLD}${CYAN}"
echo "  ╔══════════════════════════════════════════╗"
echo "  ║        macOS Setup Script                ║"
echo "  ║        Tahoe (26+) · Apple Silicon       ║"
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

# 判斷是否為唯一管理員，決定是否詢問電腦名稱
IS_ADMIN=false
if groups | grep -q "admin"; then
  IS_ADMIN=true
fi

# grep -c 直接輸出單一整數；|| true 防止無匹配時 pipefail 中止；再以 :-0 補預設
# （避免舊寫法在 dscl 失敗時因 pipefail + 尾端 || echo 0 而捕捉到 "0\n0"）
ADMIN_COUNT=$(dscl . -read /Groups/admin GroupMembership 2>/dev/null \
  | tr ' ' '\n' \
  | grep -cvE "^(GroupMembership:|$)" \
  || true)
ADMIN_COUNT=${ADMIN_COUNT:-0}
IS_ONLY_ADMIN=false
if [ "$ADMIN_COUNT" = "1" ]; then
  IS_ONLY_ADMIN=true
fi

COMPUTER_DISPLAY_NAME=""
COMPUTER_NETWORK_NAME=""

if [ "$IS_ADMIN" = "true" ] && [ "$IS_ONLY_ADMIN" = "true" ]; then
  echo
  echo -e "  ${BOLD}電腦名稱設定${NC}"
  echo -e "  ${DIM}（你是唯一管理員，可以設定電腦名稱）${NC}"
  read -rp "  顯示名稱（Finder / Find My，可含空格，例如 Philip M4）: " COMPUTER_DISPLAY_NAME
  read -rp "  網路名稱（終端機 / ping，不可含空格，例如 philip-m4）: " COMPUTER_NETWORK_NAME
  # LocalHostName 只接受字母/數字/連字號；把非法字元轉成連字號避免 HostName 與 LocalHostName 不一致
  if [[ -n "$COMPUTER_NETWORK_NAME" ]]; then
    SANITIZED_NETWORK_NAME=$(echo "$COMPUTER_NETWORK_NAME" | tr ' ' '-' | tr -cd 'A-Za-z0-9-')
    if [[ "$SANITIZED_NETWORK_NAME" != "$COMPUTER_NETWORK_NAME" ]]; then
      warn "網路名稱已正規化：$COMPUTER_NETWORK_NAME → $SANITIZED_NETWORK_NAME"
      COMPUTER_NETWORK_NAME="$SANITIZED_NETWORK_NAME"
    fi
  fi
else
  warn "非管理員或非唯一管理員，跳過電腦名稱設定"
fi

echo
echo -e "  ${BOLD}Git 設定${NC}（留空則跳過）"
read -rp "  Git user.name: " GIT_NAME
read -rp "  Git email: " GIT_EMAIL

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
menu_add "sys_tcc_whitelist"   "隱私權白名單（op / Claude / Ghostty FDA，免反覆彈窗）"

menu_add "__SECTION__瀏覽器" ""
menu_add "app_chrome"     "Google Chrome"
menu_add "app_brave"      "Brave"

menu_add "__SECTION__密碼 / 安全" ""
menu_add "app_1password"  "1Password"

menu_add "__SECTION__音樂" ""
menu_add "app_spotify"    "Spotify"

menu_add "__SECTION__生產力" ""
menu_add "app_rectangle"      "Rectangle（視窗管理）"
menu_add "app_raycast"        "Raycast（啟動器，取代 Spotlight）"
menu_add "app_stats"          "Stats（Menubar 系統監控）"
menu_add "app_pearcleaner"    "Pearcleaner（App 完整移除）"
menu_add "app_monitorcontrol" "MonitorControl（外接螢幕亮度）"
menu_add "app_obsidian"       "Obsidian（知識庫）"

menu_add "__SECTION__滑鼠" ""
menu_add "app_logitech"   "Logi Options+"

menu_add "__SECTION__輸入法" ""
menu_add "app_rime"       "鼠鬚管（Squirrel）+ 嗯蝦米"

menu_add "__SECTION__Terminal" ""
menu_add "app_ghostty"    "Ghostty（JetBrains Mono Nerd Font + Solarized Dark）"
menu_add "dev_ohmyzsh"    "Oh My Zsh + Plugins"
menu_add "dev_starship"   "Starship Prompt（Solarized Dark 風格）"
menu_add "dev_vim"        "Vim + vim-plug + Solarized Dark"

menu_add "__SECTION__編輯器" ""
menu_add "app_vscode"     "VS Code + settings.json + 擴充功能"

menu_add "__SECTION__開發環境" ""
menu_add "dev_python"          "pyenv + pyenv-virtualenv（Python 最新穩定版）"
menu_add "dev_node"            "nvm（Node 24 LTS）+ pnpm"
menu_add "dev_git"             "Git 設定 + global .gitignore + SSH config"
menu_add "dev_homebrew_update" "Homebrew 每週自動更新（LaunchAgent）"

menu_run "選擇要安裝的模組（全部預設勾選）"

# ── 相依性：Starship / pyenv / nvm 的 shell 初始化只寫在 dev_ohmyzsh 的 .zshrc ──
# 若選了這些工具卻沒選 Oh My Zsh，會裝好但在互動 shell 永遠不啟用。自動補上 dev_ohmyzsh。
if ! menu_is_on "dev_ohmyzsh"; then
  if menu_is_on "dev_starship" || menu_is_on "dev_python" || menu_is_on "dev_node"; then
    for i in "${!MENU_KEYS[@]}"; do
      if [[ "${MENU_KEYS[$i]}" == "dev_ohmyzsh" ]]; then
        MENU_STATE[$i]=1
      fi
    done
    warn "Starship/pyenv/nvm 需要 .zshrc 初始化，已自動勾選 Oh My Zsh"
  fi
fi


# ════════════════════════════════════════════════════════════════════
#  區塊 7：確認最終清單
# ════════════════════════════════════════════════════════════════════

clear
echo
echo -e "${BOLD}  安裝清單確認${NC}"
echo
# 修正：原本誤用未定義的 $COMPUTER_NAME，應為 $COMPUTER_DISPLAY_NAME
echo -e "  使用者：${BOLD}$USER_DISPLAY_NAME${NC}  電腦名稱：${BOLD}$COMPUTER_DISPLAY_NAME${NC}"
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

# ── sudo 鎖定（確認後立即取得，並在背景保持存活）─────────────────────
# 長腳本安裝期間 sudo 可能過期，用背景 loop 每 60 秒刷新 token
sudo -v || fail "需要管理員密碼才能繼續"
# 背景子 shell 必須 set +e：否則 sudo token 過期時 `sudo -n true` 回傳非零，
# 在繼承的 set -e 下會殺掉整個 keepalive（剛好就在它該補刷的時刻）。
# 先檢查父進程存活再 sleep，讓父進程死亡後最多殘留一個閒置 sleep。
( set +e
  while true; do
    kill -0 "$$" 2>/dev/null || exit 0
    sudo -n true 2>/dev/null
    sleep 60
  done ) &
SUDO_KEEPALIVE_PID=$!
trap 'kill "$SUDO_KEEPALIVE_PID" 2>/dev/null' EXIT INT TERM


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
if [[ "$MACOS_VERSION" != 26.* ]]; then
  warn "建議使用 macOS Tahoe (26+)，目前版本 $MACOS_VERSION"
fi

if [ -n "$COMPUTER_DISPLAY_NAME" ] && [ -n "$COMPUTER_NETWORK_NAME" ]; then
  sudo scutil --set ComputerName  "$COMPUTER_DISPLAY_NAME"
  sudo scutil --set HostName      "$COMPUTER_NETWORK_NAME"
  sudo scutil --set LocalHostName "$COMPUTER_NETWORK_NAME"
  log "顯示名稱：$COMPUTER_DISPLAY_NAME"
  log "網路名稱：$COMPUTER_NETWORK_NAME"
fi


# ════════════════════════════════════════════════════════════════════
#  區塊 9：Xcode Command Line Tools
# ════════════════════════════════════════════════════════════════════

section "Xcode Command Line Tools"

if xcode-select -p &>/dev/null; then
  log "已安裝"
else
  info "安裝 Xcode Command Line Tools..."
  xcode-select --install 2>/dev/null || true
  warn "請在跳出的視窗點擊「安裝」，完成後按 Enter 繼續..."
  read -r || true
fi


# ════════════════════════════════════════════════════════════════════
#  區塊 10：Homebrew
# ════════════════════════════════════════════════════════════════════

section "Homebrew"

if command -v brew &>/dev/null; then
  log "已安裝，更新中..."
  brew update --quiet || warn "brew update 失敗，繼續執行"
else
  info "安裝 Homebrew（可能需要幾分鐘）..."
  NONINTERACTIVE=1 /bin/bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  # 以內容判斷是否已寫入，避免部分失敗重跑時 .zprofile 累積重複行
  grep -qF 'brew shellenv' "$HOME/.zprofile" 2>/dev/null \
    || echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$HOME/.zprofile"
  eval "$(/opt/homebrew/bin/brew shellenv)"
  log "Homebrew 安裝完成"
fi


# ════════════════════════════════════════════════════════════════════
#  區塊 11：系統設定（透過 defaults 寫入偏好設定資料庫）
# ════════════════════════════════════════════════════════════════════

section "系統設定"

# ── 外觀模式 ──
# 透過 System Events 需要自動化（Apple Events）權限；新帳號首次呼叫會跳授權對話框，
# 被拒或非互動時會回傳非零。用 2>/dev/null || true 防止 set -e 中止（同桌布區塊作法）。
if [ "$APPEARANCE" = "dark" ]; then
  osascript -e 'tell application "System Events" to tell appearance preferences to set dark mode to true' 2>/dev/null || true
  log "深色模式"
else
  osascript -e 'tell application "System Events" to tell appearance preferences to set dark mode to false' 2>/dev/null || true
  log "淺色模式"
fi

# ── 語言 ──
if menu_is_on "sys_lang"; then
  defaults write NSGlobalDomain AppleLanguages -array "zh-Hant" "en"
  defaults write NSGlobalDomain AppleLocale -string "zh_TW"
  defaults write NSGlobalDomain AppleCollationOrder -string "zh@collation=stroke"
  log "語言：繁體中文 > 英文"
fi

# ── 按鍵速度 ──
if menu_is_on "sys_keyrepeat"; then
  defaults write NSGlobalDomain KeyRepeat -int 2
  defaults write NSGlobalDomain InitialKeyRepeat -int 25
  log "按鍵速度（75% 快）"
fi

# ── 關閉自然捲動 ──
if menu_is_on "sys_scroll"; then
  defaults write NSGlobalDomain com.apple.swipescrolldirection -bool false
  log "自然捲動已關閉"
fi

# ── 觸控板：點一下來選按 ──
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
  defaults write com.apple.dock autohide-delay          -float  0
  defaults write com.apple.dock autohide-time-modifier  -float  0.3
  defaults write com.apple.dock show-recents            -bool   false
  defaults write com.apple.dock mineffect               -string "scale"
  defaults write com.apple.dock minimize-to-application -bool   false
  log "Dock 外觀完成（圖示稍後設定）"
fi

# ── 螢幕保護 + 睡眠密碼 ──
# idleTime（螢幕保護啟動時間）仍可由 defaults 設定。
# 但「睡眠後立即要求密碼」在 macOS 26 已不再由 askForPassword/askForPasswordDelay 控制
# （這兩個 key 寫入會成功但無實際效果），須改由 sysadminctl 或系統設定處理。
if menu_is_on "sys_screensaver"; then
  defaults write com.apple.screensaver idleTime -int 1200
  defaults -currentHost write com.apple.screensaver idleTime -int 1200
  # 「立即要求密碼」改走手動：sysadminctl -screenLock 需要使用者密碼，
  # 在腳本中自動帶入既不安全也可能卡住終端機，故只設定螢幕保護時間
  log "螢幕保護：20 分鐘（密碼鎖定需手動設定）"
  add_manual "系統設定 → 鎖定畫面 → 「在開始螢幕保護程式或顯示器關閉後要求密碼」設為「立即」"
fi

# ── 熱角 ──
# 2=指揮中心 / 3=應用程式視窗 / 4=桌面 / 5=螢幕保護
if menu_is_on "sys_hotcorner"; then
  defaults write com.apple.dock wvous-tl-corner -int 5
  defaults write com.apple.dock wvous-tl-modifier -int 0
  defaults write com.apple.dock wvous-tr-corner -int 4
  defaults write com.apple.dock wvous-tr-modifier -int 0
  defaults write com.apple.dock wvous-bl-corner -int 3
  defaults write com.apple.dock wvous-bl-modifier -int 0
  defaults write com.apple.dock wvous-br-corner -int 2
  defaults write com.apple.dock wvous-br-modifier -int 0
  log "熱角設定完成"
fi

# ── 截圖 ──
if menu_is_on "sys_screenshot"; then
  SCREENSHOT_DIR="$HOME/Desktop/Screenshots"
  mkdir -p "$SCREENSHOT_DIR"
  defaults write com.apple.screencapture location      "$SCREENSHOT_DIR"
  defaults write com.apple.screencapture type           -string "png"
  defaults write com.apple.screencapture disable-shadow -bool   true
  killall SystemUIServer 2>/dev/null || true
  log "截圖：~/Desktop/Screenshots（無陰影）"
fi

# ── Finder ──
if menu_is_on "sys_finder"; then
  defaults write com.apple.finder ShowPathbar              -bool   true
  defaults write com.apple.finder ShowStatusBar            -bool   true
  defaults write NSGlobalDomain   AppleShowAllExtensions   -bool   true
  defaults write com.apple.finder FXPreferredViewStyle     -string "Nlsv"
  defaults write com.apple.finder FXDefaultSearchScope     -string "SCcf"
  defaults write com.apple.finder _FXShowPosixPathInTitle  -bool   true
  defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false
  defaults write com.apple.finder ShowRecentTags           -bool   false
  defaults write com.apple.finder NewWindowTarget          -string "PfHm"
  defaults write com.apple.finder NewWindowTargetPath      -string "file://$HOME/"
  killall Finder 2>/dev/null || true
  log "Finder 設定完成"
  add_manual "Finder → 設定 → 側邊欄，手動勾選需要顯示的項目（iCloud Drive、AirDrop、外接硬碟等）"
fi

# ── 選單列 ──
if menu_is_on "sys_menubar"; then
  defaults write com.apple.controlcenter "NSStatusItem Visible Bluetooth" -bool true
  defaults write com.apple.controlcenter "NSStatusItem Visible Sound"     -bool true

  if pmset -g batt 2>/dev/null | grep -q "InternalBattery"; then
    defaults write com.apple.controlcenter "NSStatusItem Visible Battery" -bool true
    # macOS 11+ 電池百分比由 Control Center 管理；舊的 com.apple.menuextra.battery
    # ShowPercent 在 macOS 26 已無效（domain 不存在）
    defaults -currentHost write com.apple.controlcenter BatteryShowPercentage -bool true
    defaults write com.apple.controlcenter BatteryShowPercentage -bool true
    log "選單列：藍芽 + 音量 + 電池百分比"
  else
    log "選單列：藍芽 + 音量（無內建電池）"
  fi
  # 這些狀態列項目由 ControlCenter 程序擁有，killall SystemUIServer 不會重載它們
  killall ControlCenter 2>/dev/null || true
  killall SystemUIServer 2>/dev/null || true
fi

# ── 桌面：素色岩石色 ──
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

  # 先 bootout 舊的（若已載入），否則 bootstrap 在第二次執行會無效，
  # launchd 會繼續跑舊定義，編輯過的 plist 不會生效
  launchctl bootout "gui/$(id -u)/com.user.keyboard-remap" 2>/dev/null \
    || launchctl unload "$LAUNCH_AGENT_DIR/com.user.keyboard-remap.plist" 2>/dev/null \
    || true
  launchctl bootstrap "gui/$(id -u)" "$LAUNCH_AGENT_DIR/com.user.keyboard-remap.plist" 2>/dev/null \
    || launchctl load "$LAUNCH_AGENT_DIR/com.user.keyboard-remap.plist" 2>/dev/null \
    || true

  log "外接鍵盤 Command ↔ Option 互換（開機自動生效）"
fi

# ── Spotlight 停用，輸入法切換改 Command+Space ──
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

# ── .DS_Store 不寫入網路/外接磁碟 ──
if menu_is_on "sys_ds_store"; then
  defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
  defaults write com.apple.desktopservices DSDontWriteUSBStores     -bool true
  log ".DS_Store 不寫入網路/外接磁碟"
fi

# ── 時區 ──
# macOS Tahoe 在終端機未具備全磁碟存取權限（FDA）時 systemsetup 會失敗
# 嘗試 systemsetup，失敗則透過 launchd 設定並通知手動補完
if menu_is_on "sys_timezone"; then
  if sudo systemsetup -settimezone "Asia/Taipei" 2>/dev/null; then
    sudo systemsetup -setusingnetworktime on 2>/dev/null || true
    log "時區：台北，網路自動同步"
  else
    warn "systemsetup 失敗（macOS Tahoe 需要全磁碟存取權限）"
    warn "嘗試備選方式設定時區..."
    sudo /usr/sbin/systemsetup -settimezone "Asia/Taipei" 2>/dev/null || true
    add_manual "若時區不正確：系統設定 → 一般 → 日期與時間 → 時區設為「台北」"
  fi
fi

# ── macOS 自動更新 ──
if menu_is_on "sys_autoupdate"; then
  sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticCheckEnabled            -bool true
  sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticDownload                -bool true
  sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticallyInstallMacOSUpdates -bool true
  sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate CriticalUpdateInstall            -bool true
  sudo defaults write /Library/Preferences/com.apple.commerce       AutoUpdate                       -bool true
  log "macOS 自動更新已開啟"
fi

# ── 防火牆 ──
if menu_is_on "sys_firewall"; then
  sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on
  sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode on
  log "防火牆已開啟（含隱身模式）"
fi

# ── FileVault ──
if menu_is_on "sys_filevault"; then
  FV_STATUS=$(fdesetup status 2>/dev/null || echo "unknown")
  if echo "$FV_STATUS" | grep -q "FileVault is On"; then
    log "FileVault 已開啟"
    add_manual "確認 FileVault Recovery Key 已存入 1Password"
  else
    info "開啟 FileVault..."
    # 只有 enable 真正成功（且印出 Recovery Key）才顯示「請存入」橫幅與成功訊息；
    # 失敗時不可謊稱已顯示金鑰、也不可謊稱已開啟。
    if sudo fdesetup enable -user "$(whoami)"; then
      echo
      echo -e "${BOLD}${RED}  ══════════════════════════════════════════${NC}"
      echo -e "${BOLD}${RED}  ⚠  FileVault Recovery Key 已顯示如上${NC}"
      echo -e "${BOLD}${RED}  ⚠  請立即複製並存入 1Password！${NC}"
      echo -e "${BOLD}${RED}  ══════════════════════════════════════════${NC}"
      echo
      read -rp "  已存入 1Password？[y/N] " FV_CONFIRM
      if [[ ! "$FV_CONFIRM" =~ ^[Yy]$ ]]; then
        warn "請務必在繼續前將 Recovery Key 存入 1Password，否則遺失後無法解鎖磁碟"
        read -rp "  確認已存入，繼續？[y/N] " FV_CONFIRM2
        [[ ! "$FV_CONFIRM2" =~ ^[Yy]$ ]] && fail "請先存入 Recovery Key 再繼續"
      fi
      log "FileVault 已開啟"
      add_manual "確認 FileVault Recovery Key 已存入 1Password"
    else
      warn "FileVault 開啟失敗（未顯示 Recovery Key）"
      add_manual "手動開啟 FileVault：系統設定 → 隱私權與安全性 → FileVault → 開啟"
    fi
  fi
fi


# ════════════════════════════════════════════════════════════════════
#  區塊 12：套件安裝
# ════════════════════════════════════════════════════════════════════

section "安裝套件"

if menu_is_on "app_chrome";        then brew_cask "google-chrome";    fi
if menu_is_on "app_brave";         then brew_cask "brave-browser";    fi
if menu_is_on "app_1password"; then
  brew_cask "1password"
  brew_cask "1password-cli"
fi
if menu_is_on "app_spotify";       then brew_cask "spotify";          fi
if menu_is_on "app_rectangle";     then brew_cask "rectangle";        fi
if menu_is_on "app_raycast";       then brew_cask "raycast";          fi
if menu_is_on "app_stats";         then brew_cask "stats";            fi
if menu_is_on "app_pearcleaner";   then brew_cask "pearcleaner";      fi
if menu_is_on "app_monitorcontrol";then brew_cask "monitorcontrol";   fi
if menu_is_on "app_obsidian";      then brew_cask "obsidian";         fi
if menu_is_on "app_logitech";      then brew_cask "logi-options+";    fi

if menu_is_on "app_vscode"; then
  brew_cask "visual-studio-code"
fi

if menu_is_on "app_ghostty"; then
  brew_cask "ghostty"
  brew_cask "font-jetbrains-mono-nerd-font"
fi


# ════════════════════════════════════════════════════════════════════
#  區塊 13：Dock 圖示順序（必須在套件安裝後執行）
#
#  使用區塊 4 的 python3/plistlib 方案，確保 tile-data 以
#  Dictionary 型別寫入，不會因 XML 字串型別導致設定失效
# ════════════════════════════════════════════════════════════════════

if menu_is_on "sys_dock"; then
  # 區塊 11 已用 defaults write 設定 Dock 外觀，cfprefsd 仍持有該 domain 的記憶體快取。
  # 若直接用 plistlib 寫檔，cfprefsd 之後會用舊快取覆蓋掉我們寫入的 persistent-apps。
  # 先重啟 cfprefsd 讓它放棄快取，之後改從磁碟重新讀取。
  killall cfprefsd 2>/dev/null || true

  # System Preferences.app 在 Tahoe 已移除（改名 System Settings.app），故不再列入
  if dock_reset; then
    for app in \
      "/System/Library/CoreServices/Finder.app" \
      "/Applications/Safari.app" \
      "/Applications/Google Chrome.app" \
      "/Applications/Brave Browser.app" \
      "/Applications/Spotify.app" \
      "/Applications/Ghostty.app" \
      "/Applications/Visual Studio Code.app" \
      "/Applications/Obsidian.app" \
      "/System/Applications/System Settings.app"
    do
      add_dock_app "$app" || warn "Dock 加入失敗：$(basename "$app")"
    done
    killall Dock 2>/dev/null || true
    log "Dock 圖示設定完成"
  else
    warn "Dock 重設失敗，略過圖示排列"
  fi
fi


# ════════════════════════════════════════════════════════════════════
#  區塊 14：輸入法（鼠鬚管 + 嗯蝦米）
# ════════════════════════════════════════════════════════════════════

section "輸入法"

if menu_is_on "app_rime"; then
  # cask 已更名為 squirrel-app（舊名 squirrel 僅靠 old_tokens 別名暫時可用）
  brew_cask "squirrel-app"
  RIME_DIR="$HOME/Library/Rime"
  mkdir -p "$RIME_DIR"

  if [ -f "$RIME_DIR/liur.schema.yaml" ]; then
    log "嗯蝦米已存在"
  else
    info "安裝嗯蝦米..."
    if curl -fsSL https://raw.githubusercontent.com/hsuanyi-chou/rime-liur/master/rime_liur_installer.sh | bash; then
      log "嗯蝦米完成"
    else
      warn "嗯蝦米自動安裝失敗"
      add_manual "手動執行：curl -fsSL https://raw.githubusercontent.com/hsuanyi-chou/rime-liur/master/rime_liur_installer.sh | bash"
    fi
  fi

  # 備份既有 default.custom.yaml（這是 Rime 使用者自訂檔，避免重跑時清掉使用者設定）
  backup_if_exists "$RIME_DIR/default.custom.yaml"
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
#
#  用 install -d 建立設定目錄（明確指定 755 權限），
#  避免父目錄非當前使用者所有時 mkdir 預設寫入失敗
# ════════════════════════════════════════════════════════════════════

section "Ghostty"

if menu_is_on "app_ghostty"; then
  install -d -m 755 "$HOME/.config"
  install -d -m 755 "$HOME/.config/ghostty"

  cat >"$HOME/.config/ghostty/config" <<'GHOSTTY'
# ── 外觀 ───────────────────────────────────────────
theme              = "iTerm2 Solarized Dark"
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
#  設計決策：
#  - nvm plugin 從 plugins 列表移除：.zshrc 已手動 source nvm.sh，
#    保留 plugin 會造成雙重載入（plugin 用 lazy-load，手動用即載）
#  - 1password plugin 只在安裝 1password-cli 時才加入
#  - 刪除與 OMZ git plugin 重複的 git aliases（gs ga gc gp gl gd gb gco glog）
#    OMZ git plugin 已內建這些 aliases（部分行為略有差異），重複定義造成
#    設定檔噪音或覆蓋掉 OMZ 較完整的版本
# ════════════════════════════════════════════════════════════════════

section "Oh My Zsh"

if menu_is_on "dev_ohmyzsh"; then
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

  # 備份現有 .zshrc（避免破壞性覆蓋使用者既有設定）
  backup_if_exists "$HOME/.zshrc"

  # ── 動態決定 plugins 列表（1password plugin 需要 op CLI）──────────
  # 因 heredoc 用 <<'ZSHRC'（防止展開），plugins 需分段寫入。
  # 寫入暫存檔再原子 mv，避免三段寫入中途中斷留下未閉合 plugins=( 的壞檔
  cat >"$HOME/.zshrc.tmp" <<'ZSHRC_HEAD'
# ════════════════════════════════════════════════
#  .zshrc — 由 setup.sh 自動產生
# ════════════════════════════════════════════════

# ── nvm 環境（必須在 source omz 之前 export）────
export NVM_DIR="$HOME/.nvm"

# ── Oh My Zsh ──────────────────────────────────
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME=""                    # 由 Starship 負責 prompt
DISABLE_AUTO_UPDATE="true"
DISABLE_MAGIC_FUNCTIONS="true"

plugins=(
  git
  macos
  history
  colored-man-pages
ZSHRC_HEAD

  # 1password plugin 只有安裝 1password-cli 才加入，避免 op 不存在時啟動報錯
  if menu_is_on "app_1password"; then
    echo "  1password" >> "$HOME/.zshrc.tmp"
  fi

  # nvm 省略：.zshrc 下方已手動 source，加入 plugin 會雙重載入
  cat >>"$HOME/.zshrc.tmp" <<'ZSHRC_PLUGINS'
  zsh-autosuggestions
  zsh-syntax-highlighting
  you-should-use
  zsh-autocomplete
)

source $ZSH/oh-my-zsh.sh

# ── Homebrew ────────────────────────────────────
eval "$(/opt/homebrew/bin/brew shellenv)"

# ── Starship Prompt ─────────────────────────────
if command -v starship &>/dev/null; then
  eval "$(starship init zsh)"
fi

# ── pyenv ───────────────────────────────────────
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
if command -v pyenv &>/dev/null; then
  eval "$(pyenv init --path)"
  eval "$(pyenv init -)"
  eval "$(pyenv virtualenv-init -)"
fi

# ── nvm（手動載入，不使用 OMZ nvm plugin 避免雙重初始化）──
[ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && \. "/opt/homebrew/opt/nvm/nvm.sh"
[ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ] && \
  \. "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"

# ── 1Password SSH Agent ─────────────────────────
export SSH_AUTH_SOCK="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"

# ── 語言環境 ────────────────────────────────────
export LANG=zh_TW.UTF-8
export LC_ALL=zh_TW.UTF-8
export LC_CTYPE=zh_TW.UTF-8

# ── Editor ──────────────────────────────────────
export GIT_EDITOR=vim
export EDITOR=vim
export VISUAL=vim

# ── Aliases ─────────────────────────────────────
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

# ── Git aliases 已由 OMZ git plugin 提供，不重複定義 ──
# （ga gst gc gp gl gd gb gco glog 等皆由 git plugin 覆蓋）

# ── ZSH 補全外觀 ────────────────────────────────
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#6c7a89"
ZSH_AUTOSUGGEST_USE_ASYNC=1
ZSHRC_PLUGINS

  # 三段都成功才原子換上正式檔
  mv -f "$HOME/.zshrc.tmp" "$HOME/.zshrc"
  log ".zshrc 完成"
fi


# ════════════════════════════════════════════════════════════════════
#  區塊 17：Starship Prompt
# ════════════════════════════════════════════════════════════════════

section "Starship"

if menu_is_on "dev_starship"; then
  brew_pkg "starship"
  install -d -m 755 "$HOME/.config"
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
# ════════════════════════════════════════════════════════════════════

section "Vim"

if menu_is_on "dev_vim"; then
  brew_pkg "vim"

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

  # 備份現有 .vimrc，避免覆蓋使用者既有設定
  backup_if_exists "$HOME/.vimrc"

  cat >"$HOME/.vimrc" <<'VIMRC'
" ── vim-plug ───────────────────────────────────────
call plug#begin('~/.vim/plugged')
  Plug 'altercation/vim-colors-solarized'
  Plug 'vim-airline/vim-airline'
  Plug 'vim-airline/vim-airline-themes'
  Plug 'preservim/nerdtree'
  Plug 'airblade/vim-gitgutter'
  Plug 'tpope/vim-fugitive'
  Plug 'dense-analysis/ale'
  Plug 'Yggdroot/indentLine'
  Plug 'tpope/vim-commentary'
  Plug 'jiangmiao/auto-pairs'
call plug#end()

" ── 外觀 ────────────────────────────────────────────
syntax enable
set background=dark
silent! colorscheme solarized
let g:airline_theme='solarized'
let g:airline_powerline_fonts=1
let g:airline#extensions#tabline#enabled=1

" ── 行號 ────────────────────────────────────────────
set number
set relativenumber
set cursorline

" ── UI ──────────────────────────────────────────────
set showcmd
set showmatch
set wildmenu
set wildmode=list:longest
set laststatus=2
set scrolloff=8
set sidescrolloff=8

" ── 搜尋 ────────────────────────────────────────────
set incsearch
set hlsearch
set ignorecase
set smartcase

" ── 縮排 ────────────────────────────────────────────
set expandtab
set shiftwidth=2
set tabstop=2
set smartindent
set autoindent

" ── 檔案 ────────────────────────────────────────────
set encoding=utf-8
set fileencoding=utf-8
set fileencodings=utf-8,big5,gbk,latin1
set autoread
set noswapfile
set nobackup
set nowritebackup
set hidden

" ── 滑鼠 ────────────────────────────────────────────
set mouse=a

" ── 語法縮排規則 ─────────────────────────────────────
filetype plugin indent on
autocmd BufNewFile,BufRead *.py         set tabstop=4 shiftwidth=4
autocmd BufNewFile,BufRead *.yaml,*.yml setlocal tabstop=2 shiftwidth=2
autocmd BufNewFile,BufRead *.json       setlocal tabstop=2 shiftwidth=2
autocmd BufNewFile,BufRead *.md         setlocal tabstop=2 shiftwidth=2 wrap linebreak

" ── NERDTree ────────────────────────────────────────
map <C-n> :NERDTreeToggle<CR>
let NERDTreeShowHidden=1
let NERDTreeMinimalUI=1
let NERDTreeIgnore=['\.DS_Store$', '\.git$', '__pycache__']

" ── ALE ─────────────────────────────────────────────
let g:ale_linters = {'python': ['flake8'], 'yaml': ['yamllint']}
let g:ale_fixers  = {'python': ['autopep8'], '*': ['remove_trailing_lines', 'trim_whitespace']}
let g:ale_fix_on_save=1

" ── 快捷鍵 ──────────────────────────────────────────
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

  if vim +PlugInstall +qall &>/dev/null; then
    log "Vim plugins 完成"
  else
    warn "Vim plugins 自動安裝失敗"
    add_manual "開啟 Vim → 執行 :PlugInstall"
  fi
fi


# ════════════════════════════════════════════════════════════════════
#  區塊 19：VS Code 設定
#
#  解決「冷啟動」問題：
#  優先用 PATH 中的 code，找不到則嘗試 App 包內的絕對路徑
# ════════════════════════════════════════════════════════════════════

section "VS Code"

if menu_is_on "app_vscode"; then
  CODE_BIN="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
  if command -v code &>/dev/null; then
    CODE_CMD="code"
  elif [[ -x "$CODE_BIN" ]]; then
    CODE_CMD="$CODE_BIN"
  else
    CODE_CMD=""
  fi

  if [[ -n "$CODE_CMD" ]]; then
    for ext in \
      "ms-python.python" \
      "eamodio.gitlens" \
      "redhat.vscode-yaml" \
      "vscodevim.vim" \
      "1Password.op-vscode" \
      "esbenp.prettier-vscode"
    do
      if "$CODE_CMD" --install-extension "$ext" --force &>/dev/null; then
        log "$ext ✓"
      else
        warn "$ext 安裝失敗"
      fi
    done
  else
    warn "VS Code CLI（code 指令）未找到"
    add_manual "VS Code → Command Palette → 'Shell Command: Install code in PATH'，再重新執行腳本"
  fi

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
  # 先安裝編譯依賴（openssl、sqlite 等），否則 pyenv compile 會失敗
  for dep in openssl@3 readline sqlite xz zlib; do
    brew_pkg "$dep"
  done

  brew_pkg "pyenv"
  brew_pkg "pyenv-virtualenv"

  export PYENV_ROOT="$HOME/.pyenv"
  export PATH="$PYENV_ROOT/bin:$PATH"
  eval "$(pyenv init --path)" 2>/dev/null || true

  # 設定 OpenSSL 編譯旗標，確保 ssl module 正確連結
  export LDFLAGS="-L$(brew --prefix openssl@3)/lib"
  export CPPFLAGS="-I$(brew --prefix openssl@3)/include"
  export PKG_CONFIG_PATH="$(brew --prefix openssl@3)/lib/pkgconfig"

  if ! command -v pyenv &>/dev/null; then
    warn "pyenv 不可用，跳過 Python 版本安裝"
    add_manual "新終端機執行：pyenv install <version> && pyenv global <version>"
  else
    # 用 awk 掃描完整清單取最後一個符合 3.x.x 純數字版本的穩定版
    # 比 grep | tail 更健壯：支援三位數版號（3.14.x）並確保不匹配 rc/dev
    LATEST_PYTHON=$(pyenv install --list 2>/dev/null \
      | awk '/^[[:space:]]+3\.[0-9]+\.[0-9]+[[:space:]]*$/{v=$1} END{if(v!="")print v}' \
      || true)

    if [ -z "$LATEST_PYTHON" ]; then
      warn "找不到 Python 最新穩定版"
      add_manual "新終端機執行：pyenv install --list 找版本後安裝"
    else
      info "Python 最新穩定版：$LATEST_PYTHON"
      if pyenv versions 2>/dev/null | grep -qF "$LATEST_PYTHON"; then
        log "Python $LATEST_PYTHON 已安裝"
      else
        info "安裝 Python $LATEST_PYTHON（需幾分鐘）..."
        if pyenv install "$LATEST_PYTHON"; then
          log "Python $LATEST_PYTHON ✓"
        else
          warn "Python 安裝失敗"
          add_manual "新終端機執行：pyenv install $LATEST_PYTHON && pyenv global $LATEST_PYTHON"
        fi
      fi
      pyenv global "$LATEST_PYTHON" 2>/dev/null || true
      log "Python 設定完成"
    fi
  fi

  # 清除編譯旗標，避免影響後續其他套件
  unset LDFLAGS CPPFLAGS PKG_CONFIG_PATH
fi

# ── Node：nvm + Node 24 LTS + pnpm ──
# NVM_DIR 設為 $HOME/.nvm（nvm 儲存 Node 版本的位置）
# nvm 本體從 Homebrew 安裝（/opt/homebrew/opt/nvm/nvm.sh），不從 $NVM_DIR 載入
if menu_is_on "dev_node"; then
  brew_pkg "nvm"

  export NVM_DIR="$HOME/.nvm"
  # 用 install -d 確保目錄存在且屬於當前使用者
  install -d -m 755 "$NVM_DIR"

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
  if [ -n "$GIT_NAME" ];  then git config --global user.name  "$GIT_NAME";  fi
  if [ -n "$GIT_EMAIL" ]; then git config --global user.email "$GIT_EMAIL"; fi

  git config --global core.editor          "vim"
  git config --global init.defaultBranch   "main"
  git config --global pull.rebase          false
  git config --global core.autocrlf        input
  git config --global core.precomposeunicode true
  git config --global fetch.prune          true
  git config --global diff.colorMoved      zebra
  git config --global merge.conflictstyle  diff3
  git config --global rebase.autoStash     true

  git config --global gpg.format           ssh
  git config --global gpg.ssh.program      "/Applications/1Password.app/Contents/MacOS/op-ssh-sign"
  git config --global commit.gpgsign       false

  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"

  # 預先加入 GitHub 的 SSH host fingerprint，避免第一次連線時互動式確認卡住自動化流程
  ssh-keyscan -H github.com >> "$HOME/.ssh/known_hosts" 2>/dev/null || true
  # 去重複，保持 known_hosts 乾淨
  sort -u "$HOME/.ssh/known_hosts" -o "$HOME/.ssh/known_hosts" 2>/dev/null || true
  chmod 600 "$HOME/.ssh/known_hosts"

  # SSH config
  # StrictHostKeyChecking accept-new：自動接受新主機金鑰（不接受已變更的），
  # 解決第一次連 GitHub 的 fingerprint 確認卡住問題
  cat >"$HOME/.ssh/config" <<SSH_CONFIG
# ── GitHub ─────────────────────────────────────
Host github.com
  HostName github.com
  User git
  StrictHostKeyChecking accept-new
  IdentityAgent "$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"

# ── 全域預設 ────────────────────────────────────
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

# ── 環境變數 ─────────────────────────────────────
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

  # 先 bootout 舊的（若已載入），確保第二次執行能套用編輯後的 plist
  launchctl bootout "gui/$(id -u)/com.user.brew-update" 2>/dev/null \
    || launchctl unload "$LAUNCH_AGENT_DIR/com.user.brew-update.plist" 2>/dev/null \
    || true
  launchctl bootstrap "gui/$(id -u)" "$LAUNCH_AGENT_DIR/com.user.brew-update.plist" 2>/dev/null \
    || launchctl load "$LAUNCH_AGENT_DIR/com.user.brew-update.plist" 2>/dev/null \
    || true

  log "Homebrew 每週日凌晨 3:00 自動更新"
fi


# ════════════════════════════════════════════════════════════════════
#  區塊 21：確保所有套件都是最新版
# ════════════════════════════════════════════════════════════════════

section "更新所有套件"
info "執行 brew upgrade..."
brew upgrade 2>&1 | grep -v "^$" || true
brew upgrade --cask 2>&1 | grep -v "^$" || true
brew cleanup
log "所有套件已更新"


# ════════════════════════════════════════════════════════════════════
#  區塊 22：隱私權白名單（TCC）
#
#  直接寫入 ~/Library/.../TCC.db，讓 op、Claude CLI、Claude.app
#  的「取用其他 App 的資料」不再每次重複彈窗。
#
#  kTCCServiceSystemPolicyAppBundles = "取用其他 App 的資料"
#  kTCCServiceSystemPolicyAllFiles   = 完整磁碟存取（FDA）
#
#  user 層 TCC.db 不需要 FDA 就能寫入（自己的 ~/Library）
#  system 層 TCC.db（FDA）需要 sudo，且本身需 FDA 才能寫入；
#  如果失敗改用 add_manual 通知手動補設
# ════════════════════════════════════════════════════════════════════

if menu_is_on "sys_tcc_whitelist"; then
  section "隱私權白名單"

  USER_TCC="$HOME/Library/Application Support/com.apple.TCC/TCC.db"
  SYS_TCC="/Library/Application Support/com.apple.TCC/TCC.db"
  TCC_NOW=$(date +%s)

  # 寫入 user 層 TCC：kTCCServiceSystemPolicyAppBundles
  # client_type 0=bundle ID, 1=可執行檔路徑
  _tcc_user_grant() {
    local service=$1 client=$2 client_type=$3
    # 已是允許就跳過
    local cur
    cur=$(sqlite3 "$USER_TCC" \
      "SELECT auth_value FROM access WHERE service='$service' AND client='$client';" \
      2>/dev/null || true)
    [[ "$cur" == "2" ]] && return 0
    sqlite3 "$USER_TCC" \
      "INSERT OR REPLACE INTO access
       (service,client,client_type,auth_value,auth_reason,auth_version,
        csreq,policy_id,indirect_object_identifier_type,
        indirect_object_identifier,indirect_object_code_identity,flags,last_modified)
       VALUES
       ('$service','$client',$client_type,2,4,1,
        NULL,NULL,0,'UNUSED',NULL,0,$TCC_NOW);" 2>/dev/null
  }

  # ── op CLI ──
  if menu_is_on "app_1password" && command -v op &>/dev/null; then
    OP_PATH=$(command -v op)
    if _tcc_user_grant "kTCCServiceSystemPolicyAppBundles" "$OP_PATH" 1; then
      log "op → 取用其他 App 的資料 ✓"
    else
      warn "op TCC 寫入失敗"
      add_manual "允許「op」取用其他 App 的資料（系統提示時選允許）"
    fi
  fi

  # ── Claude.app ──
  if [[ -d "/Applications/Claude.app" ]]; then
    if _tcc_user_grant "kTCCServiceSystemPolicyAppBundles" "com.anthropic.claude" 0; then
      log "Claude.app → 取用其他 App 的資料 ✓"
    else
      warn "Claude.app TCC 寫入失敗"
      add_manual "允許「Claude.app」取用其他 App 的資料（系統提示時選允許）"
    fi
  fi

  # ── claude CLI ──
  if command -v claude &>/dev/null; then
    CLAUDE_PATH=$(command -v claude)
    if _tcc_user_grant "kTCCServiceSystemPolicyAppBundles" "$CLAUDE_PATH" 1; then
      log "claude CLI → 取用其他 App 的資料 ✓"
    else
      warn "claude CLI TCC 寫入失敗"
      add_manual "允許「claude」取用其他 App 的資料（系統提示時選允許）"
    fi
  fi

  # ── Ghostty：完整磁碟存取（system 層，讓子程序不必逐一詢問）──
  # 需要終端機本身已有 FDA 才能寫入 system TCC.db
  if menu_is_on "app_ghostty"; then
    if sudo sqlite3 "$SYS_TCC" \
      "INSERT OR REPLACE INTO access
       (service,client,client_type,auth_value,auth_reason,auth_version,
        csreq,policy_id,indirect_object_identifier_type,
        indirect_object_identifier,indirect_object_code_identity,flags,last_modified)
       VALUES
       ('kTCCServiceSystemPolicyAllFiles','com.mitchellh.ghostty',0,2,4,1,
        NULL,NULL,0,'UNUSED',NULL,0,$TCC_NOW);" 2>/dev/null; then
      log "Ghostty → 完整磁碟存取 ✓"
    else
      warn "Ghostty FDA 無法自動設定（終端機本身需先有 FDA 才能寫入）"
      add_manual "系統設定 → 隱私權與安全性 → 完整磁碟存取 → 新增 Ghostty"
    fi
  fi
fi


# ════════════════════════════════════════════════════════════════════
#  區塊 23：手動步驟彙整
# ════════════════════════════════════════════════════════════════════

HAS_CHROME=false; HAS_BRAVE=false; HAS_1PW=false
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
#  區塊 24：套用所有系統設定
# ════════════════════════════════════════════════════════════════════

section "套用設定"

killall Finder SystemUIServer Dock 2>/dev/null || true
/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u 2>/dev/null || true
log "系統設定已套用"


# ════════════════════════════════════════════════════════════════════
#  區塊 25：完成畫面
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
