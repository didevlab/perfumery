<div align="center">

# crt-compositor

**A CRT effect applied by the Linux compositor — curvature, scanlines, phosphor mask and vignette over _any_ terminal window, terminal-independent.**

[![Shell: Bash](https://img.shields.io/badge/shell-bash-4EAA25.svg)](https://www.gnu.org/software/bash/)
[![Platform: Linux](https://img.shields.io/badge/platform-Linux-1793D1.svg)]()
[![License](https://img.shields.io/badge/license-MIT-green.svg)]()

</div>

## What it is

`crt-compositor` makes your terminal look like an old CRT monitor — but instead of
relying on the terminal emulator to render a shader, it asks the **compositor** (the
program that draws windows on screen) to do it. Because the compositor sits *above*
every window, the effect works on **any** terminal: Alacritty, kitty, GNOME Terminal,
foot, xterm, WezTerm, st, Terminator, and more.

## Why

Most terminal emulators **cannot run GLSL shaders** — only a few (Ghostty, Kitty via
hacks, Windows Terminal) do. The compositor, however, *always* renders your windows
with the GPU and on supported compositors can inject a fragment shader into that
pipeline. So we apply the CRT look one level up, and it becomes terminal-independent.

## Quick Start

```bash
# One-liner (remote)
wget -qO- https://raw.githubusercontent.com/didevlab/perfumery/main/crt-compositor/install.sh | bash
```

or from a checkout:

```bash
git clone https://github.com/didevlab/perfumery
cd perfumery/crt-compositor
./install.sh
```

The installer detects your session (X11 vs Wayland/Hyprland), installs the right
shader, and wires it up. It is idempotent and never clobbers an existing shader rule.

## How it works

| Session | Compositor | Scope | Mechanism |
|---------|-----------|-------|-----------|
| **X11** | picom | **Per-window** (terminals only) | `window-shader-fg-rule` matching terminal window classes |
| **Wayland** | Hyprland | **Whole screen** | `decoration:screen_shader` |

- **X11 / picom** — the installer drops `picom-crt.glsl` into
  `~/.config/picom/shaders/crt.glsl` and adds a `window-shader-fg-rule` to
  `~/.config/picom.conf` that applies the shader **only** to common terminal window
  classes. Other windows are untouched.
- **Wayland / Hyprland** — the installer drops `hyprland-crt.frag` into
  `~/.config/hypr/shaders/crt.frag`. Hyprland's screen shaders apply to the
  **entire screen**, not a single window — there is no per-window shader hook in
  Hyprland today, so the whole desktop gets the CRT look.

> **Linux-only & experimental.** Compositor shader hooks vary across versions and
> GPUs. This recipe targets X11+picom and Wayland+Hyprland and should be tested on
> your machine. See [docs/SETUP.md](docs/SETUP.md) and
> [docs/TECHNICAL.md](docs/TECHNICAL.md).

## Platform support

| Platform | Supported here? | Where to go |
|----------|:---------------:|-------------|
| Linux — X11 (picom) | Yes | this recipe |
| Linux — Wayland (Hyprland) | Yes (whole-screen) | this recipe |
| Linux — KWin / Mutter / Sway | No | port the shader to that compositor's effect system |
| macOS | No | use a shader-capable terminal — e.g. the **Ghostty** recipe (`retro-theme`) |
| Windows | No | use the **Windows Terminal** HLSL shader (`retro-theme`) |

## Folder structure

```
crt-compositor/
├── install.sh                 # idempotent, dual-mode (local checkout or curl/wget pipe)
├── README.md
├── shaders/
│   ├── picom-crt.glsl         # X11 / picom window shader (per-window)
│   └── hyprland-crt.frag      # Wayland / Hyprland screen shader (whole screen)
└── docs/
    ├── SETUP.md               # step-by-step install + verify
    └── TECHNICAL.md           # how the shader hooks work, extension points
```

## Troubleshooting

**Problem**: Nothing changed after install (X11).
**Solution**: picom must be restarted to read the new rule:
`pkill picom; picom --config ~/.config/picom.conf &`. Confirm your terminal's window
class is in the rule (`xprop WM_CLASS`, then click the terminal).

**Problem**: The whole screen is curved on Hyprland, not just the terminal.
**Solution**: Expected. Hyprland only supports whole-screen shaders. Use the X11/picom
path if you want per-window.

**Problem**: `window-shader-fg-rule` already exists in `picom.conf`.
**Solution**: The installer refuses to edit it and prints a snippet — merge the shader
path into your existing rule by hand.

**Problem**: My terminal isn't affected on X11.
**Solution**: Its window class isn't in the rule. Find it with `xprop WM_CLASS` and add
it to the `class_g = '...'` list in `picom.conf`.

**Problem**: Black bars / corners around windows.
**Solution**: That's the curvature clipping the edges — tune the `curve()` constants in
the shader (see [docs/TECHNICAL.md](docs/TECHNICAL.md)).

## License

MIT
