# Setup Guide

Step-by-step guide to recover a frozen USB bus on Linux — first with a manual
one-shot reset, then by installing the `xhci-watchdog` systemd daemon that
detects the freeze and resets the controller automatically.

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Find Your xHCI PCI Address](#2-find-your-xhci-pci-address)
3. [Manual Reset (One-Shot)](#3-manual-reset-one-shot)
4. [Install the Watchdog Daemon](#4-install-the-watchdog-daemon)
5. [Verify It Works](#5-verify-it-works)
6. [Optional: Disable USB Autosuspend (GRUB)](#6-optional-disable-usb-autosuspend-grub)
7. [Troubleshooting](#7-troubleshooting)
8. [Next Steps](#8-next-steps)

---

## 1. Prerequisites

Before starting, make sure you have:

- [ ] A Linux machine with an **Intel xHCI USB controller** (most Intel laptops/desktops)
- [ ] `sudo` access (the reset writes to `/sys/bus/pci/...`, root-only)
- [ ] `systemd` (for the auto-recovery daemon) — `systemctl --version`
- [ ] `pciutils` installed (provides `lspci`)
- [ ] The two scripts from this folder: `fix-usb.sh`, `xhci-watchdog.sh`, and the unit `xhci-watchdog.service`

### Verify Dependencies

```bash
systemctl --version | head -1
# Expected: systemd 255 (or any recent version)

lspci -version | head -1
# Expected: pciutils version 3.x.x
# If "command not found": sudo apt install pciutils
```

---

## 2. Find Your xHCI PCI Address

The scripts default to `0000:00:14.0` (Intel Alder Lake PCH). **Your machine may
differ** — confirm it before going further.

```bash
lspci -nn | grep -i usb
# Expected (example):
# 00:14.0 USB controller [0c03]: Intel Corporation Alder Lake-P USB 3.2 xHCI [8086:51ed]
```

The leftmost field (`00:14.0`) is the short PCI address. The kernel uses the
fully-qualified form with a domain prefix: `0000:00:14.0`.

Confirm the controller is bound to the `xhci_hcd` driver:

```bash
ls -l /sys/bus/pci/drivers/xhci_hcd/ | grep 0000:
# Expected: a symlink like  0000:00:14.0 -> ../../../../devices/pci0000:00/0000:00:14.0
```

> **If your address is not `0000:00:14.0`**, edit the `DEV=` line at the top of
> **both** `fix-usb.sh` and `xhci-watchdog.sh` to match before installing.

---

## 3. Manual Reset (One-Shot)

Use this immediately when the bus freezes — no install required.

```bash
chmod +x fix-usb.sh
./fix-usb.sh
# Expected:
# Resetting xHCI 0000:00:14.0 ...
# OK. USB restarted.
```

The script prompts for your sudo password, unbinds the controller, waits 2
seconds, and re-binds it. USB peripherals drop and come back within ~3 seconds.

> **Tip:** Your laptop's internal keyboard/touchpad keep working during the
> freeze (they are PS/2 or I²C, not on the USB controller), so you can always run
> this even when external USB input is dead.

---

## 4. Install the Watchdog Daemon

The daemon follows the kernel log and resets the controller the moment it
detects a wedge — no manual action needed.

### Option A: install.sh (recommended)

`install.sh` auto-detects your xHCI PCI address (`lspci -Dnn`), patches the
daemon if it differs from the default, then installs and enables the service. It
works both from a checkout and as a remote one-liner.

```bash
# From a checkout:
./install.sh

# Or remotely (reads the same scripts from the repo):
# wget -qO- https://raw.githubusercontent.com/didevlab/perfumery/main/fix-usb/install.sh | bash
# Expected (truncated):
# ==> Detected xHCI controller: 0000:00:14.0
# ==> Installing daemon to /usr/local/bin and systemd (needs sudo)
# ==> Done. The watchdog is running.
```

### Option B: manual install

```bash
# Install the daemon script and the unit file
sudo install -m755 xhci-watchdog.sh      /usr/local/bin/xhci-watchdog.sh
sudo install -m644 xhci-watchdog.service /etc/systemd/system/xhci-watchdog.service

# Reload systemd and start the service on boot
sudo systemctl daemon-reload
sudo systemctl enable --now xhci-watchdog.service
# Expected:
# Created symlink /etc/systemd/system/multi-user.target.wants/xhci-watchdog.service -> /etc/systemd/system/xhci-watchdog.service
```

### Verify the install

```bash
sudo systemctl status xhci-watchdog.service
# Expected (truncated):
# ● xhci-watchdog.service - xHCI wedge watchdog - auto-reset the USB controller without rebooting
#      Loaded: loaded (/etc/systemd/system/xhci-watchdog.service; enabled; preset: enabled)
#      Active: active (running) since ...
#    Main PID: 1234 (xhci-watchdog.s)
```

`Active: active (running)` and `enabled` mean the daemon is up and will start on
every boot.

---

## 5. Verify It Works

The daemon logs every action under the `xhci-watchdog` tag in journald.

```bash
journalctl -t xhci-watchdog -n 20 --no-pager
# Right after install this is empty (no wedge yet) — that's normal.
```

To confirm the detect → reset path end to end, trigger a real reset by
unbinding the controller manually (this simulates the recovery the daemon
performs). The daemon does not react to a manual unbind, so this only proves the
reset mechanism — to test detection, wait for a real wedge.

```bash
# Watch the log live in one terminal:
journalctl -t xhci-watchdog -f

# When a genuine wedge happens, you will see:
# xhci-watchdog: wedge detected on 0000:00:14.0 - resetting controller
# xhci-watchdog: reset complete (0000:00:14.0)
```

You can also confirm the daemon is reading the kernel stream:

```bash
ps -ef | grep -E 'xhci-watchdog|journalctl -kf' | grep -v grep
# Expected: the xhci-watchdog.sh process plus its journalctl -kf child
```

---

## 6. Optional: Disable USB Autosuspend (GRUB)

Aggressive USB autosuspend can make marginal devices drop and contribute to
wedges. You can disable it globally with a kernel parameter.

```bash
# 1. Edit the GRUB defaults
sudo nano /etc/default/grub
```

Add `usbcore.autosuspend=-1` to `GRUB_CMDLINE_LINUX_DEFAULT`:

```bash
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash usbcore.autosuspend=-1"
```

```bash
# 2. Regenerate the GRUB config and reboot
sudo update-grub
sudo reboot
```

### Verify after reboot

```bash
cat /sys/module/usbcore/parameters/autosuspend
# Expected: -1   (autosuspend disabled)
```

---

## 7. Troubleshooting

**Problem**: `fix-usb.sh` keeps asking for a sudo password / "sudo: a password is required".
**Solution**: The script needs root to write to `/sys/bus/pci/drivers/xhci_hcd/{unbind,bind}`. Run it from an interactive terminal where you can type the password, or run the commands under `sudo -i`. Do **not** add a passwordless sudo rule for a generic `tee` — it is too broad to be safe.

**Problem**: "No such file or directory" on `/sys/bus/pci/drivers/xhci_hcd/unbind`, or the reset does nothing.
**Solution**: Your PCI address is wrong, or your controller is not named `xhci_hcd`. Re-run [section 2](#2-find-your-xhci-pci-address). Confirm the symlink exists under `/sys/bus/pci/drivers/xhci_hcd/` and that `DEV=` matches the fully-qualified address (`0000:00:14.0`, not `00:14.0`).

**Problem**: The daemon is running but never triggers during a freeze.
**Solution**: The grep pattern in `xhci-watchdog.sh` must match your kernel's wording. Capture what your kernel actually prints during a freeze with `journalctl -k | grep -i xhci`, then confirm one of these substrings appears: `Timeout while waiting for setup device command`, `not responding`, `HC died`, `Host halt`, `halt failed`, `Abort failed`. Also confirm the line contains your `DEV` address — the pattern requires it. The 30-second cooldown means at most one reset every 30 s; rapid repeated wedges are intentionally rate-limited.

**Problem**: USB freezes return within minutes even with the daemon installed.
**Solution**: The root cause is almost always an **unpowered USB hub** starving the bus of current. A USB 2.0 port supplies only ~500 mA total; several peripherals behind a passive hub exceed that. Switch to a **powered (self-powered) hub** with its own adapter. The watchdog recovers the symptom, it does not fix the power shortage.

**Problem**: Nothing works on a non-Intel machine (AMD, Qualcomm, etc.).
**Solution**: This recipe is specific to the **Intel `xhci_hcd`** driver and the `0000:00:14.0` address. On AMD the controller is usually a different driver/address (and AMD's xHCI rarely exhibits this exact wedge). Re-check with `lspci -nn | grep -i usb` and `ls /sys/bus/pci/drivers/` — if there is no `xhci_hcd` driver dir, this fix does not apply.

**Problem**: After editing the unit, `systemctl status` shows it is still using the old version.
**Solution**: systemd caches unit files. Run `sudo systemctl daemon-reload` after any change to `xhci-watchdog.service` or to the script path, then `sudo systemctl restart xhci-watchdog.service`.

---

## 8. Next Steps

- [ ] Confirm `systemctl status xhci-watchdog.service` shows `active (running)` and `enabled`
- [ ] Note your real PCI address and verify it matches `DEV=` in both scripts
- [ ] Replace any passive/unpowered USB hub with a powered one (root-cause fix)
- [ ] Optionally disable USB autosuspend via GRUB ([section 6](#6-optional-disable-usb-autosuspend-grub))
- [ ] Read [TECHNICAL.md](TECHNICAL.md) to understand the wedge and why the reset works
- [ ] After the next real freeze, check `journalctl -t xhci-watchdog` to confirm auto-recovery fired
