<div align="center">

# cool-retro-term

**A dedicated CRT terminal — scanlines, screen curvature and phosphor glow built right in, no matter which shell or multiplexer runs inside it. The cross-platform "guaranteed CRT" option for Linux and macOS.**

[![Bash](https://img.shields.io/badge/bash-5.0+-4EAA25.svg?logo=gnubash&logoColor=white)](https://www.gnu.org/software/bash/)
[![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20macOS-333.svg?logo=linux&logoColor=white)](https://kernel.org)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](../LICENSE)

</div>

[cool-retro-term](https://github.com/Swordfish90/cool-retro-term) is a terminal
emulator that emulates the look and feel of old cathode-ray-tube screens: curved
glass, scanlines, flicker, ambient glow and color bleed. Because the effect is
*part of the terminal*, you get the retro look with **any** shell (`bash`,
`zsh`, `fish`) and **any** workflow running inside it. There is no shader to wire
into another emulator and nothing terminal-specific to detect.

This recipe is a thin, idempotent installer around it. It installs
cool-retro-term with your system package manager, optionally installs `tmux`
(cool-retro-term has no native tabs or splits), and drops a sensible `tmux.conf`
so you get tabs and splits inside the CRT window — **without ever overwriting an
existing config**.

---

## Why this recipe

The sibling [retro-theme](../retro-theme/) recipe paints whichever terminal you
already use and turns on a CRT shader *where the terminal supports one* (Ghostty,
Windows Terminal). cool-retro-term takes the opposite approach: it **is** the
CRT, so the effect is guaranteed on Linux and macOS regardless of shell or
terminal features. Pick this one when you want the retro look to "just work"
everywhere.

---

## Features

- **Built-in CRT effect** — scanlines, curvature, glow, flicker and color bleed
  are rendered by the terminal itself, so they apply to anything you run inside.
- **Shell- and multiplexer-agnostic** — works the same under `bash`, `zsh`,
  `fish`, `tmux`, `screen`, an SSH session, a REPL, anything.
- **Cross-platform** — Linux (apt / dnf / pacman) and macOS (Homebrew cask).
- **tmux for tabs & splits** — cool-retro-term has no native tabs/splits, so the
  installer sets up `tmux` with mouse support and intuitive split keys.
- **Never clobbers your config** — a bundled `~/.tmux.conf` is installed *only*
  if you don't already have one.
- **Built-in profiles** — ships ready-made looks (Default Amber, Default Green,
  Vintage, IBM DOS, Apple ][) you choose from its Settings UI.

---

## Tech Stack

| Component        | Technology                                                |
|------------------|-----------------------------------------------------------|
| Terminal         | cool-retro-term (Qt / QML, OpenGL shaders)                |
| Tabs & splits    | `tmux` (cool-retro-term has none natively)                |
| Installer        | Bash + `curl`/`wget` (`install.sh`)                       |
| Package managers | apt, dnf, yum, pacman, zypper, Homebrew cask              |

---

## Quick Start

### Prerequisites

- A supported package manager: `apt`, `dnf`, `pacman` (Linux) or `brew` (macOS)
- `sudo` rights on Linux (to install system packages)
- `curl` or `wget` — only for the remote one-liner install

### Install

```bash
# Remote one-liner
wget -qO- https://raw.githubusercontent.com/didevlab/perfumery/main/cool-retro-term/install.sh | bash

# …or from a checkout
./install.sh
```

The installer is idempotent: re-running it skips anything already in place and
never touches an existing `~/.tmux.conf`. For a full walkthrough see
[docs/SETUP.md](docs/SETUP.md).

---

## Usage

### Launch the CRT terminal

```bash
cool-retro-term
```

### Tabs & splits (via tmux)

cool-retro-term has **no native tabs or splits** — use `tmux` inside it:

```bash
cool-retro-term -e tmux
```

> **Note on `-e`**: the `-e <command>` flag is finicky on some builds/versions.
> If `cool-retro-term -e tmux` fails to start, just launch `cool-retro-term`
> normally and type `tmux` in the window.

With the bundled `tmux.conf` (prefix is **Ctrl+b**):

| Keys | Action |
|------|--------|
| `Ctrl+b` then `-` | Split pane **below** (horizontal split) |
| `Ctrl+b` then `\` | Split pane **right** (vertical split) |
| `Ctrl+b` then `←/→/↑/↓` | Move between panes |
| `Ctrl+b` then `c` | New window (tab) |
| `Ctrl+b` then `n` / `p` | Next / previous window |
| `Ctrl+b` then `r` | Reload `~/.tmux.conf` |
| *(mouse)* | Click panes, drag borders, scroll for history |

### Pick a CRT profile

cool-retro-term's looks are managed through its **Settings UI** (they are GUI
profiles, not something this installer scripts). Open the app, then:

1. Click the hamburger menu (or right-click) → **Settings**.
2. Under the **Profile** dropdown choose a built-in profile, e.g.
   **Default Amber**, **Default Green**, **Vintage**, **IBM DOS** or **Apple ][**.
3. Fine-tune scanlines, curvature, glow and other knobs on the **Effects** tab.

---

## Folder Structure

```
cool-retro-term/
├── install.sh          # Idempotent installer (local or wget/curl | bash)
├── tmux.conf           # Bundled ~/.tmux.conf (mouse, -/\ splits, pane nav)
├── README.md
└── docs/
    ├── SETUP.md        # Zero-to-running walkthrough
    └── TECHNICAL.md    # How the installer works & extension points
```

---

## Troubleshooting

**Problem**: `cool-retro-term: command not found` after install.
**Solution**: Open a new terminal/session so a freshly installed binary is on
`PATH`. On macOS the app is at `/Applications/cool-retro-term.app` — launch it
from Spotlight or `open -a cool-retro-term`.

**Problem**: `cool-retro-term -e tmux` opens then immediately closes.
**Solution**: The `-e` flag is unreliable on some builds. Launch
`cool-retro-term` with no arguments, then run `tmux` inside it.

**Problem**: The installer couldn't install the package automatically.
**Solution**: Install it manually for your platform:
`sudo apt install cool-retro-term` (Debian/Ubuntu),
`sudo dnf install cool-retro-term` (Fedora),
`sudo pacman -S cool-retro-term` (Arch), or
`brew install --cask cool-retro-term` (macOS).
**Note**: cool-retro-term was removed from Flathub, so flatpak is **not**
recommended.

**Problem**: My existing `~/.tmux.conf` wasn't changed.
**Solution**: That's intentional — the installer never overwrites it. Copy the
bindings you want from [tmux.conf](tmux.conf) by hand.

**Problem**: The CRT effect feels heavy / the GPU fans spin up.
**Solution**: In **Settings → Effects** lower the bloom/glow, reduce
"Frame rate" or turn off motion blur. The effect is GPU-rendered, so lighter
settings cost less.

See [docs/SETUP.md](docs/SETUP.md#5-troubleshooting) for more.

---

## License

[MIT](../LICENSE)
