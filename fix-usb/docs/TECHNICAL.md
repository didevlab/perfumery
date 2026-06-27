# Technical Documentation

How the Intel xHCI controller wedges, why a PCI unbind/bind recovers it without
a reboot, and how the `xhci-watchdog` daemon detects and reacts to the freeze.

## Table of Contents

1. [Overview](#1-overview)
2. [Architecture](#2-architecture)
3. [Components](#3-components)
4. [The xHCI Wedge Explained](#4-the-xhci-wedge-explained)
5. [Why a PCI Unbind/Bind Recovers It](#5-why-a-pci-unbindbind-recovers-it)
6. [Why the Internal Keyboard Survives](#6-why-the-internal-keyboard-survives)
7. [Data Flow: Detect → Reset](#7-data-flow-detect--reset)
8. [Root Cause: Current Starvation](#8-root-cause-current-starvation)
9. [Extending the System](#9-extending-the-system)

---

## 1. Overview

The USB host controller on many Intel machines (`xhci_hcd` driver, typically at
PCI address `0000:00:14.0`) can enter a **wedged** state during normal use: it
stops responding to commands, peripherals drop off the bus, and re-plugging does
nothing. Historically the only recovery was a reboot.

This recipe recovers the controller **in place** by detaching it from its driver
and re-attaching it — a full re-initialization of the host controller without
touching the rest of the system.

| Component | Technology |
|-----------|------------|
| Reset mechanism | Linux PCI driver `unbind`/`bind` via sysfs |
| Driver | `xhci_hcd` (Intel xHCI host controller) |
| Detection | `journalctl -kf` (kernel ring buffer follow) + `grep` |
| Daemon runtime | systemd service (`Type=simple`, `Restart=always`) |
| Logging | `logger -t xhci-watchdog` → journald |

---

## 2. Architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│                              User space                                │
│                                                                        │
│   ┌────────────────┐        ┌──────────────────────────────────────┐  │
│   │   fix-usb.sh   │        │      xhci-watchdog.service (root)     │  │
│   │ (manual, sudo) │        │  ExecStart=/usr/local/bin/           │  │
│   │                │        │            xhci-watchdog.sh           │  │
│   └───────┬────────┘        └──────────────────┬───────────────────┘  │
│           │                                     │                       │
│           │ write DEV                           │ follow + grep         │
│           │ to unbind/bind                      │ kernel log            │
│           v                                     v                       │
│   ┌────────────────────────────┐     ┌────────────────────────────┐   │
│   │  /sys/bus/pci/drivers/      │     │   journalctl -kf -o cat     │   │
│   │  xhci_hcd/{unbind,bind}     │     │   (kernel ring buffer)      │   │
│   └─────────────┬──────────────┘     └─────────────┬──────────────┘   │
└─────────────────┼──────────────────────────────────┼──────────────────┘
                  │ sysfs write                       │ reads
                  v                                    │
┌──────────────────────────────────────────────────────────────────────┐
│                               Kernel                                    │
│   ┌──────────────────────────────────────────────────────────────┐   │
│   │            xhci_hcd driver  ◄── unbind detaches / bind         │   │
│   │                                   re-probes & re-inits         │   │
│   └──────────────────────────────┬───────────────────────────────┘   │
│                                   │ MMIO / PCI                          │
│                                   v                                     │
│   ┌──────────────────────────────────────────────────────────────┐   │
│   │     Intel xHCI host controller  (PCI 0000:00:14.0)            │   │
│   │     ─ wedged: emits "Timeout while waiting for setup ..."     │   │
│   └──────────────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────────────┘
```

Two independent entry points drive the **same** sysfs reset: the manual
`fix-usb.sh` (human-triggered) and the `xhci-watchdog` daemon (log-triggered).

---

## 3. Components

### `fix-usb.sh`

A minimal one-shot reset. Writes the device address to the driver's `unbind`
attribute, sleeps 2 seconds, then writes it to `bind`. Uses `sudo tee` because
sysfs writes require root.

```bash
DEV="0000:00:14.0"
echo -n "$DEV" | sudo tee /sys/bus/pci/drivers/xhci_hcd/unbind > /dev/null
sleep 2
echo -n "$DEV" | sudo tee /sys/bus/pci/drivers/xhci_hcd/bind   > /dev/null
```

### `xhci-watchdog.sh`

A long-running daemon. Key parameters at the top:

| Variable | Value | Meaning |
|----------|-------|---------|
| `DEV` | `0000:00:14.0` | Fully-qualified PCI address of the xHCI controller |
| `DRV` | `/sys/bus/pci/drivers/xhci_hcd` | Driver sysfs directory holding `unbind`/`bind` |
| `COOLDOWN` | `30` | Minimum seconds between two resets (rate limit) |

It pipes `journalctl -kf` into a line-buffered `grep` and, on each matching line,
calls `reset_ctrl()` if the cooldown has elapsed. `reset_ctrl()` performs the
same unbind → sleep → bind sequence and logs the outcome via `logger`.

### `xhci-watchdog.service`

A `Type=simple` systemd unit. Runs the daemon as root after
`multi-user.target`, with `Restart=always` / `RestartSec=5` so the watchdog
comes back if it ever exits (including right after a reset blips the system).

---

## 4. The xHCI Wedge Explained

When the controller wedges, the kernel ring buffer fills with a recognizable
signature:

```
xhci_hcd 0000:00:14.0: Timeout while waiting for setup device command
usb 1-1.4.2: device descriptor read/64, error -110
usb 1-1.4.2: device not accepting address 7, error -62
usb 1-1.4-port2: unable to enumerate USB device
```

What the error codes mean:

| Code | errno | Meaning in this context |
|------|-------|-------------------------|
| `-110` | `ETIMEDOUT` | The controller never completed the USB transaction — the host stopped servicing the command ring. |
| `-62` | `ETIME` | Timer/timing expired while addressing the device — the controller is not advancing transfers. |
| "Timeout while waiting for setup device command" | — | The xHCI **command ring** stalled: the driver queued an Enable Slot / Address Device command and the controller never posted a completion event. |

Mechanically: the xHCI driver and the controller communicate through a set of
ring buffers (command ring, event ring, transfer rings) in shared memory plus a
doorbell register. A wedge is the controller ceasing to consume the command ring
or post completion events. The driver waits on a completion that never comes,
times out (`-110`/`-62`), and from then on every enumeration attempt fails. The
controller's internal state machine is stuck; the driver cannot nudge it back
through normal command submission.

---

## 5. Why a PCI Unbind/Bind Recovers It

Because the controller's *state* is corrupt but its *hardware* is fine, the cure
is to throw away all driver state and re-initialize the device from scratch —
without power-cycling the whole machine.

```
echo -n 0000:00:14.0 > /sys/bus/pci/drivers/xhci_hcd/unbind
        │
        ▼
  Kernel calls the driver's .remove() for that device:
   ─ quiesces and halts the host controller
   ─ tears down rings, IRQ handlers, and the usb_hcd
   ─ the PCI device is now driverless (but still present)

   sleep 2   ← let the controller settle / power state quiesce

echo -n 0000:00:14.0 > /sys/bus/pci/drivers/xhci_hcd/bind
        │
        ▼
  Kernel calls the driver's .probe() again:
   ─ maps MMIO, resets the host controller (HCRST)
   ─ reallocates command/event/transfer rings from clean state
   ─ re-enumerates every attached device from address 0
```

The `bind` path runs the full xHCI reset (the `HCRST` bit in the USBCMD
register) and rebuilds every ring buffer, which is exactly what a reboot would
do for this controller — only scoped to this one PCI function. This is far
cheaper than a reboot and leaves CPU, RAM, disk, and the display untouched.

This is the same machinery the kernel uses for hot-plug and for
`echo 1 > /sys/bus/pci/.../remove` followed by a rescan — `unbind`/`bind` just
keeps the PCI device enumerated and only re-runs the driver's attach logic.

---

## 6. Why the Internal Keyboard Survives

During a USB freeze the laptop's built-in keyboard and touchpad keep working —
which is what makes the manual `fix-usb.sh` usable. This is because they are
**not on the USB controller**:

- **Internal keyboard** — on laptops this is typically a **PS/2** device behind
  the embedded controller (`i8042`), or an **I²C HID** device. Either way it is
  driven by a different controller and driver, not `xhci_hcd`.
- **Internal touchpad** — usually **I²C HID** (`i2c_hid`) or PS/2, again
  independent of USB.

Only devices on the xHCI bus (external USB keyboard, mouse, hubs, drives, webcam,
etc.) freeze. The PS/2 / I²C input path is unaffected, so you can always type the
command (or let the daemon act).

---

## 7. Data Flow: Detect → Reset

```
   Kernel emits wedge message
   "xhci_hcd 0000:00:14.0: Timeout while waiting for setup device command"
                │
                ▼
   ┌──────────────────────────────────────────────┐
   │ journalctl -kf -n0 -o cat                      │   follow kernel log,
   │   (no history, raw message text)               │   stream new lines only
   └───────────────────┬────────────────────────────┘
                       │ stdout (pipe, line-buffered)
                       ▼
   ┌──────────────────────────────────────────────┐
   │ grep --line-buffered -E                        │   match DEV + one of:
   │   "${DEV}.*(Timeout...|not responding|         │   Timeout while waiting…
   │    HC died|Host halt|halt failed|Abort failed)"│   not responding / HC died
   └───────────────────┬────────────────────────────┘   Host halt / halt failed
                       │ one matched line               Abort failed
                       ▼
   ┌──────────────────────────────────────────────┐
   │ while read line:                               │
   │   now = date +%s                               │   COOLDOWN gate (30s):
   │   if (now - last >= COOLDOWN):                 │   ignore floods of
   │       last = now                               │   matching lines
   │       reset_ctrl()                             │
   └───────────────────┬────────────────────────────┘
                       │
                       ▼
   ┌──────────────────────────────────────────────┐
   │ reset_ctrl():                                  │
   │   logger "wedge detected ... resetting"        │
   │   echo DEV > $DRV/unbind                        │   ── halts & detaches
   │   sleep 2                                       │
   │   echo DEV > $DRV/bind                          │   ── re-probes & re-inits
   │   logger "reset complete (DEV)"                 │
   └───────────────────┬────────────────────────────┘
                       │
                       ▼
   USB bus blinks ~3s → all devices re-enumerate → bus healthy again
```

The **30-second cooldown** matters because a single wedge produces *many*
matching log lines (one per failed enumeration retry, per port, per device). The
cooldown collapses that burst into a single reset, then waits at least 30 s
before it will act again — preventing a reset storm.

---

## 8. Root Cause: Current Starvation

The reset recovers the symptom, but the underlying trigger is almost always
**power**, not software:

- A USB 2.0 port supplies **~500 mA** total (USB 3.x ports ~900 mA).
- A passive/unpowered hub shares that single budget across everything plugged
  into it: keyboard, mouse, webcam, flash drives, phone charging, etc.
- When peak demand exceeds the budget, devices brown out and renegotiate, and
  the controller can get stuck mid-transaction — the wedge.

The durable fix is a **powered (self-powered) USB hub** with its own power
adapter, so device current does not draw from the host port. Disabling USB
autosuspend (`usbcore.autosuspend=-1`) also helps by preventing marginal devices
from being suspended and then failing to resume cleanly.

---

## 9. Extending the System

### Adapt to a different controller / address

Edit `DEV=` in both `fix-usb.sh` and `xhci-watchdog.sh`. Find yours with
`lspci -nn | grep -i usb` and confirm the driver dir exists
(`ls /sys/bus/pci/drivers/xhci_hcd/`). If your controller uses a different
driver name, change `DRV=` too.

### Tune detection sensitivity

The `grep -E` pattern in `xhci-watchdog.sh` defines what counts as a wedge. To
catch a wording your kernel uses that isn't listed, add an alternative inside the
`(...)` group. Keep the leading `${DEV}.*` so it only fires for *your*
controller and not unrelated USB noise:

```bash
grep --line-buffered -E "${DEV}.*(Timeout while waiting for setup device command|not responding|HC died|Host halt|halt failed|Abort failed|YOUR NEW PATTERN)"
```

### Tune the cooldown

Raise `COOLDOWN` if you see the daemon resetting too aggressively, or lower it
if a single reset isn't enough to clear a stubborn wedge and you want a faster
retry. Each reset blips the bus for ~3 s, so don't set it below ~10.

### Multiple controllers

To watch more than one xHCI controller, run a second copy of the daemon with a
different `DEV` and a separate unit file (e.g. `xhci-watchdog@.service` as a
templated instance, with the address as the instance name).

### Add notifications

`reset_ctrl()` already calls `logger`. To get a desktop/notification on reset,
add a line there (e.g. `notify-send` via the logged-in user's bus, or a webhook
`curl`) — keep it non-blocking so it can't stall the recovery.
