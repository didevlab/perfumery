# Technical Documentation

How the **cool-retro-term** recipe is put together: the installer's flow, the
bundled tmux config, design decisions, and how to extend it.

## Table of Contents

1. [Overview](#1-overview)
2. [Architecture](#2-architecture)
3. [Components](#3-components)
4. [Install Flow](#4-install-flow)
5. [The Bundled tmux Config](#5-the-bundled-tmux-config)
6. [Design Decisions](#6-design-decisions)
7. [Idempotency & Safety](#7-idempotency--safety)
8. [Platform Notes](#8-platform-notes)
9. [Extending the Recipe](#9-extending-the-recipe)

---

## 1. Overview

cool-retro-term is a Qt/QML terminal emulator that renders a CRT screen with
OpenGL shaders (curvature, scanlines, glow, flicker, color bleed). Because the
effect is produced by the *terminal*, it covers everything drawn inside it —
any shell, any TUI, any multiplexer — with zero per-app configuration. That is
the whole point of this recipe versus the shader-injection approach in the
sibling `retro-theme` recipe.

The recipe itself adds no runtime code. It is purely an **installer** plus a
**tmux config**, because cool-retro-term lacks two things a daily-driver
terminal needs: tabs and splits. tmux supplies both inside the CRT window.

| Component | Technology |
|-----------|------------|
| Terminal emulator | cool-retro-term (Qt 5/6, QML, OpenGL/GLSL) |
| Tabs & splits | tmux |
| Installer | Bash (`set -euo pipefail`) |
| Asset transport | `curl` or `wget` (auto-selected) |
| Package managers | apt-get, dnf, yum, pacman, zypper, Homebrew (cask) |

---

## 2. Architecture

```
                     ┌──────────────────────────────┐
                     │          install.sh          │
                     └──────────────────────────────┘
                                   │
              ┌────────────────────┼────────────────────┐
              v                    v                    v
   ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐
   │ install CRT term │  │  install tmux    │  │ drop ~/.tmux.conf│
   │ (pm_install,     │  │ (pm_install,     │  │ (fetch, only if  │
   │  cask on macOS)  │  │  best-effort)    │  │  none exists)    │
   └──────────────────┘  └──────────────────┘  └──────────────────┘
              │                    │                    │
              └──────────┬─────────┴──────────┬─────────┘
                         v                    v
                ┌──────────────────┐  ┌──────────────────┐
                │   pm_install()   │  │     fetch()      │
                │ detect pkg mgr   │  │ local copy OR    │
                │ apt/dnf/pacman/  │  │ download() from  │
                │ brew --cask …    │  │ REPO_RAW         │
                └──────────────────┘  └──────────────────┘
                                              │
                                       ┌──────────────┐
                                       │  download()  │
                                       │ curl OR wget │
                                       └──────────────┘
```

At runtime there is no daemon and no engine — the user simply launches
`cool-retro-term` (optionally `cool-retro-term -e tmux`).

```
┌──────────────────────────────────────────────┐
│  cool-retro-term window (CRT shader applied)  │
│  ┌────────────────────────────────────────┐  │
│  │  tmux session                           │  │
│  │  ┌───────────────┐ ┌─────────────────┐  │  │
│  │  │ pane (shell)  │ │ pane (shell)    │  │  │
│  │  └───────────────┘ └─────────────────┘  │  │
│  └────────────────────────────────────────┘  │
└──────────────────────────────────────────────┘
   The CRT effect wraps everything inside, including tmux.
```

---

## 3. Components

| File | Purpose |
|------|---------|
| `install.sh` | Idempotent installer: package install + tmux config drop |
| `tmux.conf` | Bundled `~/.tmux.conf` — mouse, `-`/`\` splits, pane nav |
| `README.md` | Overview, quick start, usage |
| `docs/SETUP.md` | Zero-to-running walkthrough |
| `docs/TECHNICAL.md` | This document |

### Installer helper functions

| Function | Signature | Responsibility |
|----------|-----------|----------------|
| `say`  | `say <msg>` | Green `==>` status line |
| `warn` | `warn <msg>` | Yellow `[!]` warning line |
| `download` | `download <url> <out>` | Fetch a URL via `curl` or `wget` (whichever exists) |
| `fetch` | `fetch <rel> <dest>` | Copy `<rel>` from the local checkout, else `download` from `REPO_RAW` |
| `pm_install` | `pm_install <pkg> [brew_mode]` | Install `<pkg>` via the detected package manager; `brew_mode=cask` uses `brew install --cask` |

`REPO_RAW` points at
`https://raw.githubusercontent.com/didevlab/perfumery/main/cool-retro-term`, so
the same script works whether run from a clone or piped from the network.

---

## 4. Install Flow

Step by step, in order:

1. **Resolve `SRC`** — the directory the script lives in (empty when piped via
   `curl|bash`). `fetch` uses it to prefer local files over the network.
2. **Install cool-retro-term**
   - If `cool-retro-term` is on `PATH`, or `/Applications/cool-retro-term.app`
     exists (macOS), skip.
   - Else call `pm_install cool-retro-term cask`. On Linux the trailing `cask`
     argument is ignored (only `brew` reads it); on macOS it triggers
     `brew install --cask cool-retro-term`.
   - On failure, print copy-paste manual-install commands for each platform.
3. **Install tmux** — skip if present, else `pm_install tmux` (best-effort; a
   failure only warns, since tmux is optional sugar).
4. **Drop `~/.tmux.conf`**
   - If it already exists → warn and **leave it untouched**.
   - Else `fetch tmux.conf ~/.tmux.conf`.
5. **Print the final help** — how to launch, the `-e tmux` quirk, the tmux key
   bindings, and where to choose a CRT profile in Settings.

The script runs under `set -euo pipefail`; best-effort steps wrap their failures
(`|| warn …`, `>/dev/null 2>&1`) so they don't abort the whole install.

---

## 5. The Bundled tmux Config

`tmux.conf` is intentionally small and conventional (keeps the default `Ctrl+b`
prefix so it won't surprise anyone):

| Setting | Value | Why |
|---------|-------|-----|
| `mouse` | `on` | Click panes, drag borders, scroll — friendly in a GUI window |
| `bind -` | `split-window -v` | Split **below**; mnemonic: `-` looks like a horizontal divider |
| `bind \` | `split-window -h` | Split **right**; mnemonic: `\` looks like a vertical divider |
| `bind Left/Down/Up/Right` | `select-pane -L/-D/-U/-R` | Arrow-key pane navigation |
| `base-index` / `pane-base-index` | `1` | Number windows/panes from 1 (matches keyboard) |
| `renumber-windows` | `on` | No gaps after closing a window |
| `history-limit` | `10000` | Larger scrollback |
| `escape-time` | `10` | Snappier ESC (helps vi/neovim) |
| `mode-keys` | `vi` | vi-style keys in copy mode |
| `bind r` | `source-file ~/.tmux.conf` | Reload config in place |

New panes inherit `#{pane_current_path}` so a split opens in the same directory.
The default `"` and `%` split bindings are unbound to avoid confusion.

---

## 6. Design Decisions

- **Why cool-retro-term at all?** It is the only mainstream terminal where the
  CRT look is intrinsic. "Guaranteed CRT" means no dependency on a host
  terminal's shader support — unlike `retro-theme`, which can only enable a real
  effect on Ghostty / Windows Terminal.
- **Why bundle tmux?** cool-retro-term deliberately has no tabs/splits. Rather
  than recommend a second terminal, tmux delivers tabs (windows) and splits
  (panes) inside the one CRT window.
- **Why GUI profiles instead of scripting them?** cool-retro-term stores its
  visual profiles through its Qt Settings UI; there is no stable, documented CLI
  or file format for swapping them reliably. The docs therefore guide users to
  the Settings dropdown instead of pretending to script it.
- **Why no flatpak path?** cool-retro-term was removed from Flathub, so
  recommending flatpak would send users to a dead end.

---

## 7. Idempotency & Safety

- **Re-runnable**: each step checks for the thing it installs and skips if
  present (`command -v cool-retro-term`, the macOS `.app` path, `command -v
  tmux`, the `~/.tmux.conf` existence check).
- **Never clobbers user config**: an existing `~/.tmux.conf` is left exactly as
  is; the installer only *adds* a config when none exists.
- **No sudo surprises**: privilege escalation only happens inside `pm_install`
  for the Linux package managers, exactly when installing a package.
- **Transport-agnostic**: works with either `curl` or `wget`; absent both, it
  warns instead of failing silently.

---

## 8. Platform Notes

| OS | Package manager | Install command used | Binary location |
|----|-----------------|----------------------|-----------------|
| Debian/Ubuntu | apt-get | `sudo apt-get install -y cool-retro-term` | `/usr/bin/cool-retro-term` |
| Fedora/RHEL | dnf / yum | `sudo dnf install -y cool-retro-term` | `/usr/bin/cool-retro-term` |
| Arch | pacman | `sudo pacman -Sy --noconfirm cool-retro-term` | `/usr/bin/cool-retro-term` |
| openSUSE | zypper | `sudo zypper install -y cool-retro-term` | `/usr/bin/cool-retro-term` |
| macOS | Homebrew | `brew install --cask cool-retro-term` | `/Applications/cool-retro-term.app` |

The `-e <command>` launch flag (`cool-retro-term -e tmux`) is honored on most
builds but is unreliable on some versions; the docs always offer the
launch-then-run-tmux fallback.

---

## 9. Extending the Recipe

**Change the tmux defaults**: edit `tmux.conf`. Because the installer only
installs it when absent, contributors testing changes should remove or rename
their own `~/.tmux.conf` first, or copy the new file by hand.

**Support another package manager**: add a branch to `pm_install()` following
the existing pattern, e.g.:

```bash
elif command -v apk >/dev/null 2>&1; then sudo apk add "$pkg"
```

**Ship an extra bundled asset**: drop the file in `cool-retro-term/`, then
`fetch "<name>" "<dest>"` in `install.sh`. `fetch` automatically prefers the
local copy in a checkout and falls back to `REPO_RAW` for the remote one-liner.

**Add a different multiplexer** (e.g. zellij): mirror the tmux block —
`command -v zellij` guard, best-effort `pm_install zellij`, and a config drop
guarded by an existing-file check.

See [SETUP.md](SETUP.md) for the user-facing walkthrough and
[README.md](../README.md) for the overview.
