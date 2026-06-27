#!/usr/bin/env bash
# xhci-watchdog — detects when the Intel xHCI controller wedges and resets it
# via PCI unbind/bind, without rebooting the machine. Runs as a systemd service (root).
set -u

DEV="0000:00:14.0"                       # xHCI controller (lspci: Alder Lake PCH USB)
DRV="/sys/bus/pci/drivers/xhci_hcd"
COOLDOWN=30                              # minimum seconds between resets
last=0

reset_ctrl() {
  logger -t xhci-watchdog "wedge detected on ${DEV} - resetting controller"
  if echo -n "$DEV" > "${DRV}/unbind" 2>/dev/null; then
    sleep 2
    echo -n "$DEV" > "${DRV}/bind" 2>/dev/null
    logger -t xhci-watchdog "reset complete (${DEV})"
  else
    logger -t xhci-watchdog "ERROR: unbind failed for ${DEV}"
  fi
}

# Follow the kernel log; fire when the controller wedges.
journalctl -kf -n0 -o cat 2>/dev/null | \
  grep --line-buffered -E "${DEV}.*(Timeout while waiting for setup device command|not responding|HC died|Host halt|halt failed|Abort failed)" | \
  while IFS= read -r _line; do
    now=$(date +%s)
    if (( now - last >= COOLDOWN )); then
      last=$now
      reset_ctrl
    fi
  done
