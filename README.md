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
| **[retro-theme](retro-theme/)** | A retro/CRT look for your terminal — **detects the terminal you're in and applies the theme automatically**. Works with Ghostty, Windows Terminal (WSL), GNOME Terminal, Terminator, kitty, Alacritty, WezTerm and iTerm2. |

## One-line install

```bash
# fix-usb — auto-recovery daemon for a wedged USB controller
wget -qO- https://raw.githubusercontent.com/didevlab/perfumery/main/fix-usb/install.sh | bash

# retro-theme — terminal-agnostic retro/CRT theme switcher
wget -qO- https://raw.githubusercontent.com/didevlab/perfumery/main/retro-theme/install.sh | bash
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
└── retro-theme/            # Terminal-agnostic retro/CRT theme switcher
    ├── install.sh          # One-command installer
    ├── bin/retro-theme     # Detects the terminal and applies the theme
    ├── themes/             # Bundled color palettes (.conf)
    ├── shaders/            # CRT and neon-glow GLSL shaders (Ghostty)
    ├── config              # Ghostty config template
    ├── zshrc-snippet.zsh   # Alias + zsh completion
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
