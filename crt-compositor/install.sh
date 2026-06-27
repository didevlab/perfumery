#!/usr/bin/env bash
# Installer for crt-compositor — a CRT effect applied by the Linux COMPOSITOR,
# so it works over ANY terminal window (terminal-independent).
#
# Two supported backends:
#   - X11  + picom    -> per-window shader, wired to terminal classes only
#   - Wayland + Hyprland -> whole-screen shader (affects everything, not only the terminal)
#
# Works two ways:
#   1) From a checkout:    ./install.sh
#   2) One-liner (remote): wget -qO- <raw-url>/crt-compositor/install.sh | bash
#
# Idempotent. Does not overwrite an existing window-shader rule (warns instead).
#
# NOTE FOR REVIEWERS / CI: This targets X11+picom and Wayland+Hyprland and CANNOT
# be auto-tested in CI (it needs a running compositor + GPU). `bash -n` passes;
# the actual effect must be tested on the user's machine. Linux-only, experimental.
set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/didevlab/perfumery/main/crt-compositor"
SRC="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"

PICOM_DIR="$HOME/.config/picom"
PICOM_SHADER_DIR="$PICOM_DIR/shaders"
PICOM_SHADER="$PICOM_SHADER_DIR/crt.glsl"
PICOM_CONF="$HOME/.config/picom.conf"

HYPR_DIR="$HOME/.config/hypr"
HYPR_SHADER_DIR="$HYPR_DIR/shaders"
HYPR_SHADER="$HYPR_SHADER_DIR/crt.frag"

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
# No brew here — compositors are Linux-only.
pm_install() {
  local pkg="$1"
  if   command -v apt-get >/dev/null 2>&1; then sudo apt-get update -qq && sudo apt-get install -y "$pkg"
  elif command -v dnf     >/dev/null 2>&1; then sudo dnf install -y "$pkg"
  elif command -v yum     >/dev/null 2>&1; then sudo yum install -y "$pkg"
  elif command -v pacman  >/dev/null 2>&1; then sudo pacman -Sy --noconfirm "$pkg"
  elif command -v zypper  >/dev/null 2>&1; then sudo zypper install -y "$pkg"
  else return 1; fi
}

# Ensure a command exists, installing its package if missing. ensure_cmd <cmd> <pkg>
ensure_cmd() {
  command -v "$1" >/dev/null 2>&1 && return 0
  warn "$1 not found — attempting to install '$2'..."
  pm_install "$2" >/dev/null 2>&1 && say "installed $2" || warn "could not auto-install $2 — install it manually"
}

# --- Session detection -------------------------------------------------------
# Prefer XDG_SESSION_TYPE, then fall back to WAYLAND_DISPLAY / DISPLAY.
detect_session() {
  local t="${XDG_SESSION_TYPE:-}"
  if [[ -z "$t" ]]; then
    if   [[ -n "${WAYLAND_DISPLAY:-}" ]]; then t="wayland"
    elif [[ -n "${DISPLAY:-}" ]];        then t="x11"
    fi
  fi
  printf '%s' "$t"
}

is_hyprland() {
  [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] || command -v hyprctl >/dev/null 2>&1
}

# --- X11 / picom -------------------------------------------------------------
install_picom() {
  say "Detected X11 session — setting up the picom CRT window shader."
  ensure_cmd picom picom

  say "Installing shader into $PICOM_SHADER"
  mkdir -p "$PICOM_SHADER_DIR"
  fetch "shaders/picom-crt.glsl" "$PICOM_SHADER"

  # The picom rule maps the shader to common terminal window classes only.
  local rule
  rule=$(cat <<EOF
window-shader-fg-rule = [
  "$PICOM_SHADER : class_g = 'Alacritty' || class_g = 'kitty' || class_g = 'org.gnome.Terminal' || class_g = 'Terminator' || class_g = 'foot' || class_g = 'XTerm' || class_g = 'st-256color' || class_g = 'org.wezfurlong.wezterm'"
];
EOF
)

  if [[ -f "$PICOM_CONF" ]] && grep -q 'window-shader-fg-rule' "$PICOM_CONF"; then
    warn "$PICOM_CONF already has a window-shader-fg-rule — not modifying it."
    warn "Merge the shader path into your existing rule manually. Suggested snippet:"
    printf '%s\n' "$rule"
  else
    say "Adding window-shader-fg-rule to $PICOM_CONF"
    mkdir -p "$(dirname "$PICOM_CONF")"
    {
      printf '\n# === crt-compositor: CRT shader on terminal windows only ===\n'
      printf '%s\n' "$rule"
    } >> "$PICOM_CONF"
  fi

  say "X11 setup complete."
  echo
  echo "  Restart picom to apply, e.g.:"
  echo "      pkill picom; picom --config \"$PICOM_CONF\" &"
  echo "  (or restart your compositor / re-login)"
  echo
  echo "  Verify:  open a terminal (Alacritty, kitty, foot, ...) — it should curve"
  echo "           with scanlines. Other windows stay untouched."
  echo "  Disable: remove the 'window-shader-fg-rule' block from $PICOM_CONF and"
  echo "           restart picom."
}

# --- Wayland / Hyprland ------------------------------------------------------
install_hyprland() {
  say "Detected Hyprland (Wayland) — setting up the CRT screen shader."
  say "Installing shader into $HYPR_SHADER"
  mkdir -p "$HYPR_SHADER_DIR"
  fetch "shaders/hyprland-crt.frag" "$HYPR_SHADER"

  warn "Hyprland screen shaders affect the WHOLE screen, not just the terminal."

  echo
  echo "  Add this line to ~/.config/hypr/hyprland.conf (under your decoration block):"
  echo
  echo "      decoration:screen_shader = ~/.config/hypr/shaders/crt.frag"
  echo
  echo "  Try it live right now (no reload needed):"
  echo
  echo "      hyprctl keyword decoration:screen_shader ~/.config/hypr/shaders/crt.frag"
  echo
  echo "  Verify:  the whole screen curves with scanlines."
  echo "  Disable live:  hyprctl keyword decoration:screen_shader \"[[EMPTY]]\""
  echo "           and remove the screen_shader line from hyprland.conf."

  if is_hyprland && command -v hyprctl >/dev/null 2>&1; then
    say "hyprctl found — applying the shader live now."
    hyprctl keyword decoration:screen_shader "$HYPR_SHADER" >/dev/null 2>&1 \
      && say "Screen shader applied. Make it permanent via hyprland.conf (above)." \
      || warn "Could not apply live — add the line to hyprland.conf manually."
  fi
}

# --- Other compositors -------------------------------------------------------
unsupported() {
  warn "Could not match a supported compositor on this session."
  echo
  echo "  crt-compositor currently supports:"
  echo "    - X11      via picom  (per-window shader on terminals)"
  echo "    - Wayland  via Hyprland (whole-screen shader)"
  echo
  echo "  Other compositors:"
  echo "    - KWin (KDE):  use Desktop Effects / write a KWin effect; or run picom-style"
  echo "                   shaders is not supported — port the shader to a KWin effect."
  echo "    - GNOME/Mutter, Sway, wlroots others: no stable per-app shader hook today."
  echo
  echo "  Shaders are bundled in this recipe under shaders/ if you want to port them."
}

# --- Main --------------------------------------------------------------------
SESSION="$(detect_session)"
say "Session type: ${SESSION:-unknown}"

if is_hyprland && [[ "$SESSION" != "x11" ]]; then
  install_hyprland
elif [[ "$SESSION" == "x11" ]]; then
  install_picom
elif [[ "$SESSION" == "wayland" ]]; then
  warn "Wayland session but Hyprland was not detected."
  unsupported
else
  unsupported
fi

say "Done!"
