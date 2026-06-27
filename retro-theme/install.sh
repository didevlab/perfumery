#!/usr/bin/env bash
# Installer for retro-theme — a terminal-agnostic theme/effect switcher.
# Installs: the `retro-theme` command, bundled themes, CRT+glow shaders (for
# Ghostty), an optional Ghostty config, and the `rt` alias + zsh autocomplete.
#
# Works two ways:
#   1) From a checkout:    ./install.sh
#   2) One-liner (remote): curl -fsSL <raw-url>/retro-theme/install.sh | bash
#
# Idempotent. Backs up an existing Ghostty config.
set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/didevlab/perfumery/main/retro-theme"
SRC="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"
GHOSTTY_DIR="$HOME/.config/ghostty"
RT_DIR="$HOME/.config/retro-theme"
BIN_DIR="$HOME/.local/bin"
ZSHRC="$HOME/.zshrc"
MARK="# === retro-theme: alias + autocomplete ==="
THEMES="amber ayu-dark ayu-light catppuccin-latte catppuccin-mocha cyberpunk-neon dracula everforest-dark github-light gruvbox-dark gruvbox-light gruvbox-material-dark kanagawa monokai night-owl nord one-dark retro-green rose-pine rose-pine-dawn solarized-dark solarized-light synthwave-84 tokyo-night"

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

# Install a package via the detected package manager (best effort, needs sudo).
pm_install() {
  local pkg="$1"
  if   command -v apt-get >/dev/null 2>&1; then sudo apt-get update -qq && sudo apt-get install -y "$pkg"
  elif command -v dnf     >/dev/null 2>&1; then sudo dnf install -y "$pkg"
  elif command -v yum     >/dev/null 2>&1; then sudo yum install -y "$pkg"
  elif command -v pacman  >/dev/null 2>&1; then sudo pacman -Sy --noconfirm "$pkg"
  elif command -v zypper  >/dev/null 2>&1; then sudo zypper install -y "$pkg"
  elif command -v brew    >/dev/null 2>&1; then brew install "$pkg"
  else return 1; fi
}

# Ensure a command exists, installing its package if missing. ensure_cmd <cmd> <pkg>
ensure_cmd() {
  command -v "$1" >/dev/null 2>&1 && return 0
  warn "$1 not found — attempting to install '$2'..."
  pm_install "$2" >/dev/null 2>&1 && say "installed $2" || warn "could not auto-install $2 — install it manually"
}

# Are we on WSL (where Windows Terminal + jq matter)?
is_wsl() { grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null || [[ -n "${WT_SESSION:-}" ]] || compgen -G '/mnt/c/Users/*' >/dev/null 2>&1; }

# 1. retro-theme command
say "Installing the retro-theme command into $BIN_DIR/"
mkdir -p "$BIN_DIR"
fetch "bin/retro-theme" "$BIN_DIR/retro-theme"
chmod +x "$BIN_DIR/retro-theme"

# 2. bundled themes
say "Installing themes into $RT_DIR/themes/"
mkdir -p "$RT_DIR/themes"
for t in $THEMES; do fetch "themes/$t.conf" "$RT_DIR/themes/$t.conf"; done

# 3. shaders — GLSL for Ghostty, HLSL for Windows Terminal
say "Installing shaders into $GHOSTTY_DIR/shaders/"
mkdir -p "$GHOSTTY_DIR/shaders"
fetch "shaders/crt.glsl"  "$GHOSTTY_DIR/shaders/crt.glsl"
fetch "shaders/glow.glsl" "$GHOSTTY_DIR/shaders/glow.glsl"
fetch "shaders/crt.hlsl"  "$GHOSTTY_DIR/shaders/crt.hlsl"
fetch "shaders/glow.hlsl" "$GHOSTTY_DIR/shaders/glow.hlsl"

# 4. optional Ghostty config (only if Ghostty is installed)
if command -v ghostty >/dev/null 2>&1; then
  if [[ -f "$GHOSTTY_DIR/config" ]]; then
    cp "$GHOSTTY_DIR/config" "$GHOSTTY_DIR/config.bak.$(date +%Y%m%d%H%M%S 2>/dev/null || echo backup)"
    warn "existing Ghostty config saved as config.bak.*"
  fi
  say "Installing Ghostty config into $GHOSTTY_DIR/config"
  fetch "config" "$GHOSTTY_DIR/config"
fi

# 5. alias + autocomplete in zshrc (only if not already present)
if [[ -f "$ZSHRC" ]] && grep -qF "$MARK" "$ZSHRC"; then
  warn "alias/autocomplete already present in $ZSHRC — skipping."
elif [[ -f "$ZSHRC" || "${SHELL:-}" == *zsh ]]; then
  say "Adding alias + autocomplete to $ZSHRC"
  tmp="$(mktemp)"; fetch "zshrc-snippet.zsh" "$tmp"
  printf '\n' >> "$ZSHRC"; cat "$tmp" >> "$ZSHRC"; rm -f "$tmp"
fi

# 6. ensure ~/.local/bin is on PATH (add to the shell rc if missing)
case ":$PATH:" in
  *":$BIN_DIR:"*) : ;;
  *)
    line='export PATH="$HOME/.local/bin:$PATH"'
    for rc in "$ZSHRC" "$HOME/.bashrc" "$HOME/.profile"; do
      [[ -f "$rc" ]] || continue
      grep -qF "$line" "$rc" || { printf '\n%s\n' "$line" >> "$rc"; say "Added ~/.local/bin to PATH in $rc"; }
    done
    export PATH="$BIN_DIR:$PATH"
    warn "PATH updated — open a new terminal or run: source ~/.zshrc"
    ;;
esac

# 7. dependencies — jq is required for the Windows Terminal adapter (WSL)
if is_wsl; then
  ensure_cmd jq jq
else
  command -v jq >/dev/null 2>&1 || warn "jq not found — install it if you plan to theme Windows Terminal."
fi

say "Done!"
echo
echo "  Reload the shell:  source ~/.zshrc"
echo "  Detect terminal:   retro-theme --detect"
echo "  Pick a theme:      retro-theme   (or: rt)"
echo "  Apply everywhere:  rt <name> --all"
echo "  Screen effect:     rt fx crt|glow|off   (Ghostty / Windows Terminal)"
echo
echo "  retro-theme detects your terminal and applies the theme automatically."
echo "  Supported: Ghostty, Windows Terminal, GNOME Terminal, Terminator,"
echo "             kitty, Alacritty, WezTerm, iTerm2."
