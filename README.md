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
| **[retro-theme](retro-theme/)** | A retro/CRT look for your terminal — **one universal installer detects your OS/terminal and sets up the theme *and* the CRT effect automatically**. 24 bundled themes, uniform everywhere. |

## One universal installer

`retro-theme` is a single entry point. Its installer **detects your OS and
terminal** and wires up the best CRT mechanism for you — reusing the dedicated
sub-installers under `retro-theme/effects/`. No need to know which one to pick.

```bash
# Works on Linux, macOS and Windows (WSL). Detects and sets everything up.
wget -qO- https://raw.githubusercontent.com/didevlab/perfumery/main/retro-theme/install.sh | bash
```

What it picks, by detection:

| Detected | CRT effect via | Handled by |
|----------|----------------|------------|
| WSL | Windows Terminal HLSL shader | core (`rt fx crt`) |
| Ghostty installed | GLSL shaders | core (`rt fx crt`) |
| Linux desktop (any terminal) | the compositor (picom / Hyprland) | `effects/compositor` |
| fallback (Linux/macOS) | a dedicated CRT terminal | `effects/cool-retro-term` |

Force a specific mechanism (skips detection):

```bash
wget -qO- .../retro-theme/install.sh | bash -s -- --effect compositor       # CRT on any Linux terminal
wget -qO- .../retro-theme/install.sh | bash -s -- --effect cool-retro-term  # dedicated CRT terminal
wget -qO- .../retro-theme/install.sh | bash -s -- --no-effect               # themes only
```

> **Themes are uniform everywhere** — the same 24 palettes apply to every
> supported terminal. Only the *screen effect* depends on the terminal/OS, and
> the orchestrator handles that for you.
>
> Prefer `curl`? Swap `wget -qO-` for `curl -fsSL`. The installer uses whichever
> of `curl`/`wget` exists and auto-installs missing deps (e.g. `jq` on WSL). It
> also works from a checkout (`./install.sh`).

### fix-usb

```bash
wget -qO- https://raw.githubusercontent.com/didevlab/perfumery/main/fix-usb/install.sh | bash
```

## Layout

```
perfumery/
├── fix-usb/                # Recover a wedged USB (xHCI) controller without rebooting
│   ├── fix-usb.sh          # Manual one-shot reset
│   ├── xhci-watchdog.sh    # systemd daemon: auto-reset on wedge
│   ├── xhci-watchdog.service
│   └── docs/               # SETUP + TECHNICAL
└── retro-theme/            # Universal retro/CRT theme + effect (one installer, all OSes)
    ├── install.sh          # ORCHESTRATOR: detects OS/terminal, sets up the effect
    ├── bin/retro-theme     # Detects the terminal and applies the theme + effect
    ├── themes/             # 24 bundled color palettes (.conf)
    ├── shaders/            # CRT + glow — GLSL (Ghostty) and HLSL (Windows Terminal)
    ├── config              # Ghostty config template
    ├── zshrc-snippet.zsh   # Alias + zsh completion
    ├── effects/            # dedicated per-mechanism installers the orchestrator calls
    │   ├── compositor/     # CRT over any terminal on Linux (picom X11 / Hyprland Wayland)
    │   └── cool-retro-term/# dedicated CRT terminal (Linux/macOS) + tmux config
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
