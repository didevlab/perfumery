#!/usr/bin/env bash
# Installer for the retro/futuristic/paper theme for Ghostty.
# Installs: CRT+glow shaders, config, the `retro-theme` command, the `rt` alias + zsh autocomplete.
#
# Works two ways:
#   1) From a checkout:   ./install.sh
#   2) One-liner (remote): curl -fsSL <raw-url>/ghostty-retro-theme/install.sh | bash
#
# Idempotent: can be run again without duplicating. Backs up an existing config.
set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/didevlab/perfumery/main/ghostty-retro-theme"
SRC="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"
GHOSTTY_DIR="$HOME/.config/ghostty"
BIN_DIR="$HOME/.local/bin"
ZSHRC="$HOME/.zshrc"
MARK="# === retro-theme: alias + autocomplete ==="
TMP=""

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

# When running remotely, stage downloaded assets in a temp dir.
if [[ -z "$SRC" || ! -f "$SRC/bin/retro-theme" ]]; then
  TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
fi

# 1. check ghostty
if ! command -v ghostty >/dev/null 2>&1; then
  warn "ghostty not found in PATH. Install it first (e.g. sudo snap install ghostty)."
fi

# 2. shaders
say "Installing shaders into $GHOSTTY_DIR/shaders/"
mkdir -p "$GHOSTTY_DIR/shaders"
fetch "shaders/crt.glsl"  "$GHOSTTY_DIR/shaders/crt.glsl"
fetch "shaders/glow.glsl" "$GHOSTTY_DIR/shaders/glow.glsl"

# 3. config (back up if it already exists)
if [[ -f "$GHOSTTY_DIR/config" ]]; then
  cp "$GHOSTTY_DIR/config" "$GHOSTTY_DIR/config.bak.$(date +%Y%m%d%H%M%S 2>/dev/null || echo backup)"
  warn "existing config saved as config.bak.*"
fi
say "Installing config into $GHOSTTY_DIR/config"
fetch "config" "$GHOSTTY_DIR/config"

# 4. retro-theme command
say "Installing the retro-theme command into $BIN_DIR/"
mkdir -p "$BIN_DIR"
fetch "bin/retro-theme" "$BIN_DIR/retro-theme"
chmod +x "$BIN_DIR/retro-theme"

# 5. alias + autocomplete in zshrc (only if not already present)
if [[ -f "$ZSHRC" ]] && grep -qF "$MARK" "$ZSHRC"; then
  warn "alias/autocomplete already present in $ZSHRC — skipping."
else
  say "Adding alias + autocomplete to $ZSHRC"
  snippet="${TMP:-$SRC}/zshrc-snippet.zsh"
  fetch "zshrc-snippet.zsh" "$snippet"
  printf '\n' >> "$ZSHRC"
  cat "$snippet" >> "$ZSHRC"
fi

# 6. PATH check
case ":$PATH:" in
  *":$BIN_DIR:"*) : ;;
  *) warn "$BIN_DIR is not in PATH. Add it: export PATH=\"$BIN_DIR:\$PATH\"" ;;
esac

# 7. ghostty as default terminal (GNOME) — optional
if command -v gsettings >/dev/null 2>&1 && command -v ghostty >/dev/null 2>&1; then
  say "Setting Ghostty as the default GNOME terminal"
  gsettings set org.gnome.desktop.default-applications.terminal exec 'ghostty' 2>/dev/null || true
  gsettings set org.gnome.desktop.default-applications.terminal exec-arg '-e' 2>/dev/null || true
fi
if command -v ghostty >/dev/null 2>&1; then
  GBIN="$(command -v ghostty)"
  warn "To make Ghostty the default x-terminal-emulator (needs sudo), run:"
  echo "    sudo update-alternatives --install /usr/bin/x-terminal-emulator x-terminal-emulator $GBIN 60"
  echo "    sudo update-alternatives --set x-terminal-emulator $GBIN"
fi

say "Done!"
echo
echo "  Reload the shell:     source ~/.zshrc"
echo "  Pick a theme:         retro-theme   (or: rt)"
echo "  Screen effect:        rt fx crt|glow|off"
echo "  Reload Ghostty:       Ctrl+Shift+,"
echo
echo "  Note: retro-theme also syncs the COLORS to Terminator, if installed"
echo "        (the CRT/glow effect is Ghostty-only)."
