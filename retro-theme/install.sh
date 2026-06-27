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
THEMES="amber dracula gruvbox-dark gruvbox-light nord retro-green solarized-light tokyo-night"

say()  { printf '\033[1;32m==>\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$1"; }

# Copy an asset from the local checkout, or download it when piped via curl.
fetch() {
  local rel="$1" dest="$2"
  if [[ -n "$SRC" && -f "$SRC/$rel" ]]; then
    cp "$SRC/$rel" "$dest"
  else
    curl -fsSL "$REPO_RAW/$rel" -o "$dest"
  fi
}

# 1. retro-theme command
say "Installing the retro-theme command into $BIN_DIR/"
mkdir -p "$BIN_DIR"
fetch "bin/retro-theme" "$BIN_DIR/retro-theme"
chmod +x "$BIN_DIR/retro-theme"

# 2. bundled themes
say "Installing themes into $RT_DIR/themes/"
mkdir -p "$RT_DIR/themes"
for t in $THEMES; do fetch "themes/$t.conf" "$RT_DIR/themes/$t.conf"; done

# 3. shaders (used by the Ghostty CRT/glow effect)
say "Installing shaders into $GHOSTTY_DIR/shaders/"
mkdir -p "$GHOSTTY_DIR/shaders"
fetch "shaders/crt.glsl"  "$GHOSTTY_DIR/shaders/crt.glsl"
fetch "shaders/glow.glsl" "$GHOSTTY_DIR/shaders/glow.glsl"

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

# 6. PATH check
case ":$PATH:" in
  *":$BIN_DIR:"*) : ;;
  *) warn "$BIN_DIR is not in PATH. Add it: export PATH=\"$BIN_DIR:\$PATH\"" ;;
esac

# 7. dependency hints
command -v jq >/dev/null 2>&1 || warn "jq not found — needed for Windows Terminal support (apt install jq)."

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
