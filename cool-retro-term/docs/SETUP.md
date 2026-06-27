# Setup Guide

Step-by-step guide to install and use **cool-retro-term** — a CRT terminal
emulator with scanlines, curvature and glow built in — plus `tmux` for tabs and
splits inside the CRT window. Works on Linux and macOS.

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Install](#2-install)
3. [Launch & Verify](#3-launch--verify)
4. [Tabs & Splits with tmux](#4-tabs--splits-with-tmux)
5. [Pick a CRT Profile](#5-pick-a-crt-profile)
6. [Troubleshooting](#6-troubleshooting)
7. [Next Steps](#7-next-steps)

---

## 1. Prerequisites

Before starting, make sure you have:

- [ ] A supported package manager:
      `apt` / `dnf` / `pacman` (Linux) or `brew` (macOS)
- [ ] `sudo` rights on Linux (system packages need it)
- [ ] `curl` **or** `wget` (only for the remote one-liner install)
- [ ] A GPU/driver that can run OpenGL (the CRT effect is GPU-rendered)

### Verify your package manager

```bash
# Linux — at least one of these should print a path
command -v apt-get; command -v dnf; command -v pacman

# macOS
command -v brew
# Expected: /opt/homebrew/bin/brew (Apple Silicon) or /usr/local/bin/brew (Intel)
```

---

## 2. Install

### Option A — remote one-liner

```bash
wget -qO- https://raw.githubusercontent.com/didevlab/perfumery/main/cool-retro-term/install.sh | bash
# …or, if you prefer curl:
curl -fsSL https://raw.githubusercontent.com/didevlab/perfumery/main/cool-retro-term/install.sh | bash
```

### Option B — from a checkout

```bash
git clone https://github.com/didevlab/perfumery.git
cd perfumery/cool-retro-term
./install.sh
```

The installer will:

1. Install **cool-retro-term** with your package manager
   (`apt` / `dnf` / `pacman` on Linux, `brew install --cask` on macOS).
2. Best-effort install **tmux** (for tabs/splits — cool-retro-term has none).
3. Install a bundled **`~/.tmux.conf`** *only if you don't already have one*
   (existing files are left untouched).

Expected tail of the output:

```
==> Done!

  Launch the CRT terminal:   cool-retro-term
  ...
```

> **Manual install** (if auto-detection fails):
> | Platform | Command |
> |----------|---------|
> | Debian/Ubuntu | `sudo apt install cool-retro-term` |
> | Fedora | `sudo dnf install cool-retro-term` |
> | Arch | `sudo pacman -S cool-retro-term` |
> | macOS | `brew install --cask cool-retro-term` |
>
> **Do not use flatpak** — cool-retro-term was removed from Flathub.

---

## 3. Launch & Verify

```bash
cool-retro-term
# Expected: a window opens with a curved, scan-lined, glowing CRT screen
```

Verify the binary is installed:

```bash
command -v cool-retro-term
# Linux  → e.g. /usr/bin/cool-retro-term
# macOS  → app bundle at /Applications/cool-retro-term.app
#          (launch with: open -a cool-retro-term)
```

Verify tmux is available:

```bash
tmux -V
# Expected: tmux 3.x
```

---

## 4. Tabs & Splits with tmux

cool-retro-term has **no native tabs or splits**. Run `tmux` inside it to get
both.

```bash
cool-retro-term -e tmux
```

> **`-e` quirk**: on some builds the `-e <command>` flag fails to launch. If the
> window doesn't start a tmux session, run `cool-retro-term` with no arguments
> and type `tmux` inside it.

The bundled `~/.tmux.conf` uses the default prefix **Ctrl+b**:

| Keys | Action |
|------|--------|
| `Ctrl+b` then `-` | Split pane **below** |
| `Ctrl+b` then `\` | Split pane **right** |
| `Ctrl+b` then `←/→/↑/↓` | Move between panes |
| `Ctrl+b` then `c` | New window (tab) |
| `Ctrl+b` then `n` / `p` | Next / previous window |
| `Ctrl+b` then `d` | Detach (re-attach later with `tmux attach`) |
| `Ctrl+b` then `r` | Reload `~/.tmux.conf` |
| *(mouse)* | Click panes, drag borders to resize, scroll for history |

Quick test:

```bash
# Inside cool-retro-term:
tmux                 # start a session
# press Ctrl+b then -   → a new pane appears BELOW
# press Ctrl+b then \   → a new pane appears to the RIGHT
# press Ctrl+b then ←   → focus moves to the left pane
```

---

## 5. Pick a CRT Profile

The retro looks are **GUI profiles** managed inside cool-retro-term — they are
not scripted by this installer.

1. Open cool-retro-term.
2. Open the hamburger menu (or right-click the window) → **Settings**.
3. In the **Profile** dropdown pick a built-in profile:
   - **Default Amber** — warm amber phosphor
   - **Default Green** — classic green phosphor
   - **Vintage** — heavy wear, flicker, distortion
   - **IBM DOS** — boxy DOS-era look
   - **Apple ][** — early Apple monitor vibe
4. Switch to the **Effects** tab to fine-tune scanlines, curvature, glow,
   flicker, brightness and frame rate.

---

## 6. Troubleshooting

**Problem**: `cool-retro-term: command not found` right after install.
**Solution**: Open a new shell/session so the new binary is on `PATH`. On macOS,
launch the app bundle: `open -a cool-retro-term` or use Spotlight.

**Problem**: `cool-retro-term -e tmux` opens and immediately closes.
**Solution**: The `-e` flag is unreliable on some versions. Launch
`cool-retro-term` without arguments and run `tmux` manually inside it.

**Problem**: The installer reported it could not install the package.
**Solution**: Install manually using the table in [section 2](#2-install). Do
**not** use flatpak — it was removed from Flathub.

**Problem**: My existing `~/.tmux.conf` wasn't replaced.
**Solution**: Intentional — the installer never overwrites it. Copy bindings you
want from the repo's `cool-retro-term/tmux.conf` by hand.

**Problem**: The window is laggy or the GPU runs hot.
**Solution**: In **Settings → Effects**, reduce bloom/glow, lower the frame
rate, and disable motion blur. The CRT effect is GPU-rendered.

**Problem**: tmux mouse selection copies differently than expected.
**Solution**: With `mouse on`, drag to select then it copies to the tmux buffer.
Hold `Shift` while selecting to use your OS's native text selection instead.

---

## 7. Next Steps

- [ ] Set cool-retro-term as your default terminal in your desktop environment.
- [ ] Pick and tweak a profile under **Settings → Effects** to taste.
- [ ] Learn a few more tmux bindings (`Ctrl+b ?` lists them all).
- [ ] Pair it with the sibling [retro-theme](../../retro-theme/) recipe if you
      also want color palettes inside the session.

See [TECHNICAL.md](TECHNICAL.md) for how the installer works and how to extend it.
