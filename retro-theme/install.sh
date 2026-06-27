#!/usr/bin/env bash
# Universal installer / orchestrator for retro-theme.
#
# One entry point for every OS: it installs the core (the `retro-theme` command,
# 24 bundled themes, GLSL+HLSL shaders, optional Ghostty config, zsh alias), then
# DETECTS your OS/terminal and sets up the best CRT effect mechanism, reusing the
# dedicated sub-installers under effects/:
#   - WSL            -> Windows Terminal HLSL (wired by retro-theme; `rt fx crt`)
#   - Ghostty        -> GLSL shaders (`rt fx crt`)
#   - Linux desktop  -> effects/compositor  (picom/Hyprland — any terminal)
#   - fallback       -> effects/cool-retro-term (dedicated CRT terminal)
#
# Effect selection: --effect auto|compositor|cool-retro-term|none  (default auto;
# `auto` asks before doing anything invasive). Also via RT_EFFECT env var.
#
# Works two ways:
#   1) From a checkout:    ./install.sh [--effect <mode>]
#   2) One-liner (remote): wget -qO- <raw-url>/retro-theme/install.sh | bash
#                          (add: | bash -s -- --effect compositor)
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

# Run a dedicated sub-installer (effects/*/install.sh), local or remote.
run_sub() {
  local rel="$1"
  if [[ -n "$SRC" && -f "$SRC/$rel" ]]; then
    bash "$SRC/$rel"
  else
    local t; t="$(mktemp)"; download "$REPO_RAW/$rel" "$t" && bash "$t"; rm -f "$t"
  fi
}

# --- effect selection (orchestration) ---
EFFECT="${RT_EFFECT:-auto}"          # auto | compositor | cool-retro-term | none
for a in "$@"; do
  case "$a" in
    --effect=*) EFFECT="${a#*=}" ;;
    --no-effect) EFFECT="none" ;;
  esac
done
# allow "--effect compositor" (space form)
prev=""; for a in "$@"; do [[ "$prev" == "--effect" ]] && EFFECT="$a"; prev="$a"; done

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

# 8. screen effect — detect the OS/terminal and set up the best CRT mechanism.
OS="$(uname -s 2>/dev/null || echo unknown)"
[[ "$EFFECT" == "none" ]] && say "Effect: skipped (--no-effect)."
if [[ "$EFFECT" == "compositor" ]]; then
  say "Effect: setting up compositor CRT (any terminal)..."; run_sub effects/compositor/install.sh
elif [[ "$EFFECT" == "cool-retro-term" ]]; then
  say "Effect: installing cool-retro-term..."; run_sub effects/cool-retro-term/install.sh
elif [[ "$EFFECT" == "auto" ]]; then
  if is_wsl; then
    say "Effect: Windows Terminal HLSL — run 'rt fx crt' (already wired by retro-theme)."
  elif command -v ghostty >/dev/null 2>&1; then
    say "Effect: Ghostty GLSL shaders — run 'rt fx crt'."
  elif [[ "$OS" == Linux ]]; then
    # desktop Linux without Ghostty: the compositor is the terminal-independent path
    if [[ "${XDG_SESSION_TYPE:-}" == wayland || "${XDG_SESSION_TYPE:-}" == x11 || -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" || -n "${WAYLAND_DISPLAY:-}" || -n "${DISPLAY:-}" ]]; then
      if [[ -t 0 ]]; then
        printf '\033[1;33m[?]\033[0m Set up the CRT effect for ANY terminal via the compositor now? [y/N] '
        read -r ans
        [[ "$ans" == y* || "$ans" == Y* ]] && run_sub effects/compositor/install.sh \
          || say "Skipped. Run later: retro-theme/effects/compositor/install.sh"
      else
        warn "Effect: for the CRT on any terminal, run: effects/compositor/install.sh (or re-run with --effect compositor)"
      fi
    else
      warn "Effect: no shader-capable terminal/compositor detected. Install Ghostty, or use --effect cool-retro-term."
    fi
  elif [[ "$OS" == Darwin ]]; then
    warn "Effect (macOS): install Ghostty for the shader effect, or re-run with --effect cool-retro-term."
  fi
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
echo
echo "  CRT effect on any terminal (Linux):  re-run with --effect compositor"
echo "  Dedicated CRT terminal (Linux/mac):  re-run with --effect cool-retro-term"
