<div align="center">

# 🧪 perfumery

**A small collection of Linux desktop & dev-environment recipes — self-contained tools and fixes that solve real, annoying problems.**

[![Shell](https://img.shields.io/badge/shell-bash%20%7C%20zsh-4EAA25.svg?logo=gnu-bash&logoColor=white)](https://www.gnu.org/software/bash/)
[![Platform](https://img.shields.io/badge/platform-Linux-333.svg?logo=linux&logoColor=white)](https://kernel.org)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

</div>

Each folder is an independent recipe with its own documentation. Copy what you
need — there is nothing to install at the repo level.

## Recipes

| Recipe | What it solves |
|--------|----------------|
| **[fix-usb](fix-usb/)** | USB freezes at runtime (Intel xHCI controller wedge). Resets the controller automatically — no reboot. |
| **[retro-theme](retro-theme/)** | A retro/CRT look for your terminal — **detects the terminal you're in and applies the theme + effect automatically**. 24 bundled themes. Effect on Ghostty (GLSL) and Windows Terminal (HLSL); colors everywhere else. |
| **[crt-compositor](crt-compositor/)** | The CRT effect over **any** terminal window on Linux, via the compositor (picom on X11, Hyprland on Wayland) — terminal-independent. |
| **[cool-retro-term](cool-retro-term/)** | A dedicated CRT terminal (built-in scanlines/curvature/glow) for Linux & macOS — the effect regardless of the shell inside. |

## Getting the CRT effect on every platform

The CRT effect is a GPU shader — only the **terminal** or the **compositor** can
render it. There is no single mechanism that covers every terminal on every OS,
so pick the path for your setup:

| Platform | Same effect via | Recipe |
|----------|-----------------|--------|
| Linux — any terminal | the compositor (picom / Hyprland) | `crt-compositor` |
| Linux / macOS — any shell | a dedicated CRT terminal | `cool-retro-term` |
| Linux / macOS | Ghostty's GLSL shaders | `retro-theme` |
| Windows (WSL) | Windows Terminal's HLSL shaders | `retro-theme` |

> **Themes are uniform everywhere** — `retro-theme` applies the same 24 palettes to
> every supported terminal. The *screen effect* is what's platform/terminal-bound.

## One-line install

```bash
# fix-usb — auto-recovery daemon for a wedged USB controller
wget -qO- https://raw.githubusercontent.com/didevlab/perfumery/main/fix-usb/install.sh | bash

# retro-theme — terminal-agnostic retro/CRT theme switcher
wget -qO- https://raw.githubusercontent.com/didevlab/perfumery/main/retro-theme/install.sh | bash

# crt-compositor — CRT over any terminal on Linux (picom/Hyprland)
wget -qO- https://raw.githubusercontent.com/didevlab/perfumery/main/crt-compositor/install.sh | bash

# cool-retro-term — dedicated CRT terminal (Linux/macOS)
wget -qO- https://raw.githubusercontent.com/didevlab/perfumery/main/cool-retro-term/install.sh | bash
```

> Prefer `curl`? Swap `wget -qO-` for `curl -fsSL`. The installers themselves use
> whichever of `curl`/`wget` is available and auto-install missing dependencies
> (e.g. `jq` for Windows Terminal). Each installer also works from a checkout
> (`./install.sh`). See each recipe's README for details.

## Layout

```
perfumery/
├── fix-usb/                # Recover a wedged USB (xHCI) controller without rebooting
│   ├── fix-usb.sh          # Manual one-shot reset
│   ├── xhci-watchdog.sh    # systemd daemon: auto-reset on wedge
│   ├── xhci-watchdog.service
│   └── docs/               # SETUP + TECHNICAL
├── retro-theme/            # Terminal-agnostic retro/CRT theme switcher
│   ├── install.sh          # One-command installer
│   ├── bin/retro-theme     # Detects the terminal and applies the theme + effect
│   ├── themes/             # 24 bundled color palettes (.conf)
│   ├── shaders/            # CRT + glow shaders — GLSL (Ghostty) and HLSL (Windows Terminal)
│   ├── config              # Ghostty config template
│   ├── zshrc-snippet.zsh   # Alias + zsh completion
│   └── docs/               # SETUP + TECHNICAL
├── crt-compositor/         # CRT over ANY terminal on Linux (compositor-level)
│   ├── install.sh          # Wires the shader into picom (X11) / Hyprland (Wayland)
│   ├── shaders/            # picom-crt.glsl + hyprland-crt.frag
│   └── docs/               # SETUP + TECHNICAL
└── cool-retro-term/        # Dedicated CRT terminal (Linux/macOS)
    ├── install.sh          # Installs cool-retro-term (+ optional tmux config)
    ├── tmux.conf           # Tabs/splits inside cool-retro-term
    └── docs/               # SETUP + TECHNICAL
```

## Conventions

- Every recipe is **self-contained** and documented with a three-tier model:
  `README.md` (overview), `docs/SETUP.md` (step-by-step), `docs/TECHNICAL.md`
  (how it works).
- Scripts are **portable**: no hardcoded machine paths; hardware-specific values
  (e.g. PCI addresses) are documented so you can find your own.
- Copy-paste-ready commands throughout.

## License

[MIT](LICENSE)
