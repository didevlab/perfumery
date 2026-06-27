#!/usr/bin/env bash
# Installer for cool-retro-term — a dedicated CRT terminal emulator that gives
# you scanlines, screen curvature and phosphor glow regardless of which shell
# or multiplexer you run inside it. This is the cross-platform (Linux + macOS)
# "guaranteed CRT" option: the effect lives in the terminal, not in a shader you
# have to wire into some other emulator.
#
# What it does:
#   1) Detects your OS / package manager and installs cool-retro-term
#      (apt / dnf / pacman / brew cask).
#   2) Best-effort installs tmux (cool-retro-term has no native tabs/splits, so
#      tmux gives you those inside the CRT window).
#   3) Drops a sensible ~/.tmux.conf ONLY if you don't already have one
#      (existing configs are backed up, never overwritten).
#
# Works two ways:
#   1) From a checkout:    ./install.sh
#   2) One-liner (remote): wget -qO- <raw-url>/cool-retro-term/install.sh | bash
#                          curl -fsSL <raw-url>/cool-retro-term/install.sh | bash
#
# Idempotent. Never clobbers an existing ~/.tmux.conf.
set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/didevlab/perfumery/main/cool-retro-term"
SRC="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"
TMUX_CONF="$HOME/.tmux.conf"

say()  { printf '\033[1;32m==>\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$1"; }

# Download a URL using whichever of curl/wget is available.
download() {
  local url="$1" out="$2"
  if command -v curl >/dev/null 2>&1; then curl -fsSL "$url" -o "$out"
  elif command -v wget >/dev/null 2>&1; then wget -qO "$out" "$url"
  else warn "neither curl nor wget found — cannot download $url"; return 1; fi
}

# Copy an asset from the local checkout, or download it when run remotely.
fetch() {
  local rel="$1" dest="$2"
  if [[ -n "$SRC" && -f "$SRC/$rel" ]]; then
    cp "$SRC/$rel" "$dest"
  else
    download "$REPO_RAW/$rel" "$dest"
  fi
}

# Install a package via the detected package manager (best effort, needs sudo on
# Linux). brew (macOS) takes an optional "cask" mode for GUI apps.
pm_install() {
  local pkg="$1" brew_mode="${2:-formula}"
  if   command -v apt-get >/dev/null 2>&1; then sudo apt-get update -qq && sudo apt-get install -y "$pkg"
  elif command -v dnf     >/dev/null 2>&1; then sudo dnf install -y "$pkg"
  elif command -v yum     >/dev/null 2>&1; then sudo yum install -y "$pkg"
  elif command -v pacman  >/dev/null 2>&1; then sudo pacman -Sy --noconfirm "$pkg"
  elif command -v zypper  >/dev/null 2>&1; then sudo zypper install -y "$pkg"
  elif command -v brew    >/dev/null 2>&1; then
    if [[ "$brew_mode" == "cask" ]]; then brew install --cask "$pkg"; else brew install "$pkg"; fi
  else return 1; fi
}

# 1. cool-retro-term — the CRT terminal itself.
if command -v cool-retro-term >/dev/null 2>&1 \
   || [[ -d "/Applications/cool-retro-term.app" ]]; then
  say "cool-retro-term already installed — skipping."
else
  say "Installing cool-retro-term…"
  # On macOS it's a Homebrew cask; on Linux the package is in the distro repos.
  if pm_install cool-retro-term cask; then
    say "cool-retro-term installed."
  else
    warn "could not auto-install cool-retro-term. Install it manually:"
    warn "  Debian/Ubuntu : sudo apt install cool-retro-term"
    warn "  Fedora        : sudo dnf install cool-retro-term"
    warn "  Arch          : sudo pacman -S cool-retro-term"
    warn "  macOS         : brew install --cask cool-retro-term"
  fi
fi

# 2. tmux — cool-retro-term has NO native tabs/splits, so tmux provides them.
if command -v tmux >/dev/null 2>&1; then
  say "tmux already installed."
else
  say "Installing tmux (for tabs/splits inside the CRT window)…"
  pm_install tmux >/dev/null 2>&1 && say "tmux installed." \
    || warn "could not auto-install tmux — install it manually if you want tabs/splits."
fi

# 3. ~/.tmux.conf — only if one doesn't already exist (back up if it does).
if [[ -f "$TMUX_CONF" ]]; then
  warn "~/.tmux.conf already exists — leaving it untouched."
  warn "  To use the bundled config, see cool-retro-term/tmux.conf in the repo."
else
  say "Installing bundled tmux config into ~/.tmux.conf"
  fetch "tmux.conf" "$TMUX_CONF"
fi

say "Done!"
echo
echo "  Launch the CRT terminal:   cool-retro-term"
echo
echo "  Start it with tmux (tabs/splits):"
echo "      cool-retro-term -e tmux"
echo "  Note: the -e flag can be finicky on some builds. If it fails, just run"
echo "      cool-retro-term"
echo "  then type 'tmux' inside the window."
echo
echo "  tmux key bindings (prefix is Ctrl+b):"
echo "      Ctrl+b -        split pane below"
echo "      Ctrl+b \\        split pane right"
echo "      Ctrl+b ←/→/↑/↓  move between panes"
echo "      Ctrl+b c        new window (tab)   Ctrl+b n / p  next / prev window"
echo "      mouse is enabled: click panes, drag borders, scroll to scrollback"
echo
echo "  Pick a CRT look:  open cool-retro-term, then the hamburger / right-click"
echo "  → Settings. Under the 'Profile' dropdown choose a built-in profile such"
echo "  as 'Default Amber', 'Default Green', 'Vintage', 'IBM DOS' or 'Apple ][',"
echo "  then tweak scanlines / curvature / glow on the Effects tab."
