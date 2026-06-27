<div align="center">

# fix-usb

**Recover a frozen USB bus on Linux without rebooting — by resetting the wedged Intel xHCI controller.**

[![Shell](https://img.shields.io/badge/shell-bash-4EAA25.svg?logo=gnu-bash&logoColor=white)](https://www.gnu.org/software/bash/)
[![systemd](https://img.shields.io/badge/systemd-service-30D475.svg)](https://systemd.io)
[![Platform](https://img.shields.io/badge/platform-Linux-333.svg?logo=linux&logoColor=white)](https://kernel.org)

</div>

On some machines the USB bus randomly freezes during use — keyboard, mouse and
peripherals stop responding and the only "fix" is a reboot. The root cause is
often the **Intel xHCI USB controller entering a wedged state**. This recipe
re-initializes the controller via a PCI unbind/bind, bringing USB back in ~3
seconds — no reboot.

> Your laptop's **internal keyboard/touchpad keep working** during the freeze
> (they are PS/2 or I²C, not on the USB controller), so you can always trigger
> the fix.

## Features

- **Manual reset** (`fix-usb.sh`) — one command to recover a frozen bus.
- **Auto-recovery daemon** (`xhci-watchdog.service`) — watches the kernel log,
  detects the wedge, and resets the controller automatically.
- **No reboot** — only the USB bus blinks for ~3 seconds.

## Symptom

USB peripherals freeze mid-session. The kernel log shows:

```
xhci_hcd 0000:00:14.0: Timeout while waiting for setup device command
usb 1-1.4.2: device descriptor read/64, error -110
usb 1-1.4-port2: unable to enumerate USB device
```

Common trigger: an **unpowered USB hub** with several peripherals (the USB 2.0
port supplies only 500 mA total).

## Quick Start

Install the auto-recovery daemon in one line (auto-detects your xHCI PCI address):

```bash
curl -fsSL https://raw.githubusercontent.com/didevlab/perfumery/main/fix-usb/install.sh | bash
```

Or from a checkout:

```bash
./install.sh
```

Prefer a manual one-shot reset when it freezes (no daemon):

```bash
./fix-usb.sh        # asks for sudo; USB blinks ~3s and comes back
```

> The scripts default to PCI address `0000:00:14.0` (Intel Alder Lake) and the
> installer auto-detects yours via `lspci`. Find it manually with
> `lspci -nn | grep -i usb` if needed.

See **[docs/SETUP.md](docs/SETUP.md)** for the full install + verification, and
**[docs/TECHNICAL.md](docs/TECHNICAL.md)** for how the reset works.

## Files

| File | Purpose |
|------|---------|
| `fix-usb.sh` | Manual one-shot reset (PCI unbind/bind of the xHCI controller). |
| `xhci-watchdog.sh` | Daemon: follows `journalctl -kf`, resets on wedge (30 s cooldown). |
| `xhci-watchdog.service` | systemd unit that runs the daemon as root, on boot. |

## Prevention

- Use a **powered USB hub** — an unpowered hub can't supply enough current and
  is the most common trigger.
- Disable aggressive USB autosuspend (kernel param `usbcore.autosuspend=-1`).

Tested on: Dell Vostro 3520, Ubuntu (GNOME), kernel 6.8, systemd 255.

## License

[MIT](../LICENSE)
