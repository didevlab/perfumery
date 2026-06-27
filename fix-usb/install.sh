#!/usr/bin/env bash
# fix-usb installer — installs the xHCI USB watchdog daemon (auto-recovery).
#
# Works two ways:
#   1) From a checkout:   ./install.sh
#   2) One-liner (remote): curl -fsSL <raw-url>/fix-usb/install.sh | bash
#
# It installs xhci-watchdog.sh + the systemd unit, then enables the service.
# Requires sudo (will prompt). Idempotent.
set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/didevlab/perfumery/main/fix-usb"
SRC="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"
TMP=""

say()  { printf '\033[1;32m==>\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$1"; }

# Download a URL using whichever of curl/wget is available.
download() {
  local url="$1" out="$2"
  if command -v curl >/dev/null 2>&1; then curl -fsSL "$url" -o "$out"
  elif command -v wget >/dev/null 2>&1; then wget -qO "$out" "$url"
  else warn "neither curl nor wget found — cannot download $url"; return 1; fi
}

# Resolve the two assets either locally (checkout) or by downloading them.
fetch() {
  local name="$1" dest="$2"
  if [[ -n "$SRC" && -f "$SRC/$name" ]]; then
    cp "$SRC/$name" "$dest"
  else
    say "Downloading $name"
    download "$REPO_RAW/$name" "$dest"
  fi
}

# Detect the Intel xHCI controller PCI address (best effort).
detect_pci() {
  local addr
  addr="$(lspci -Dnn 2>/dev/null | grep -iE 'USB controller.*xHCI' | head -1 | awk '{print $1}')"
  echo "${addr:-0000:00:14.0}"
}

main() {
  command -v lspci >/dev/null 2>&1 || warn "lspci not found — defaulting PCI address to 0000:00:14.0"
  local PCI; PCI="$(detect_pci)"
  say "Detected xHCI controller: $PCI"

  TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
  fetch "xhci-watchdog.sh"      "$TMP/xhci-watchdog.sh"
  fetch "xhci-watchdog.service" "$TMP/xhci-watchdog.service"

  # If the detected address differs from the default, patch the daemon.
  if [[ "$PCI" != "0000:00:14.0" ]]; then
    say "Patching daemon to use $PCI"
    sed -i "s|0000:00:14.0|$PCI|g" "$TMP/xhci-watchdog.sh"
  fi

  say "Installing daemon to /usr/local/bin and systemd (needs sudo)"
  sudo install -m755 "$TMP/xhci-watchdog.sh"      /usr/local/bin/xhci-watchdog.sh
  sudo install -m644 "$TMP/xhci-watchdog.service" /etc/systemd/system/xhci-watchdog.service
  sudo systemctl daemon-reload
  sudo systemctl enable --now xhci-watchdog.service

  say "Done. The watchdog is running."
  echo "  Status: systemctl status xhci-watchdog.service --no-pager"
  echo "  Actions it took: journalctl -t xhci-watchdog --no-pager"
}

main "$@"
