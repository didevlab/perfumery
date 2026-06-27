# Setup Guide

Step-by-step guide to apply the **crt-compositor** CRT effect from scratch. This is
Linux-only and experimental — test on your machine.

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Install](#2-install)
3. [X11 + picom](#3-x11--picom)
4. [Wayland + Hyprland](#4-wayland--hyprland)
5. [Verify It Works](#5-verify-it-works)
6. [Disable / Uninstall](#6-disable--uninstall)
7. [Troubleshooting](#7-troubleshooting)
8. [Next Steps](#8-next-steps)

## 1. Prerequisites

Before starting, make sure you have:

- [ ] A Linux desktop with a **compositor**: either **picom** (X11) or **Hyprland** (Wayland)
- [ ] A GPU with working OpenGL / EGL drivers
- [ ] `curl` or `wget` (for the remote one-liner)
- [ ] `sudo` access (only if picom needs to be installed)

### Check your session type

```bash
echo "$XDG_SESSION_TYPE"
# Expected: x11   (use the picom path)
#        or wayland (use the Hyprland path)
```

### Check for Hyprland

```bash
echo "$HYPRLAND_INSTANCE_SIGNATURE"
# Expected: a non-empty value if you're running Hyprland
```

## 2. Install

Remote one-liner:

```bash
wget -qO- https://raw.githubusercontent.com/didevlab/perfumery/main/crt-compositor/install.sh | bash
```

Or from a checkout:

```bash
git clone https://github.com/didevlab/perfumery
cd perfumery/crt-compositor
./install.sh
```

Expected output starts with:

```
==> Session type: x11        # or wayland
```

The installer detects the session and runs the matching path below.

## 3. X11 + picom

What the installer does:

- [ ] Installs `picom` if missing (`pm_install picom`)
- [ ] Copies the shader to `~/.config/picom/shaders/crt.glsl`
- [ ] Appends a `window-shader-fg-rule` to `~/.config/picom.conf` mapping the shader to
      terminal window classes only

Restart picom to apply:

```bash
pkill picom; picom --config ~/.config/picom.conf &
```

The rule that gets written (paths are expanded to your real `$HOME`):

```ini
# === crt-compositor: CRT shader on terminal windows only ===
window-shader-fg-rule = [
  "/home/<user>/.config/picom/shaders/crt.glsl : class_g = 'Alacritty' || class_g = 'kitty' || class_g = 'org.gnome.Terminal' || class_g = 'Terminator' || class_g = 'foot' || class_g = 'XTerm' || class_g = 'st-256color' || class_g = 'org.wezfurlong.wezterm'"
];
```

> If `picom.conf` already has a `window-shader-fg-rule`, the installer will **not**
> touch it. It prints the snippet so you can merge the shader path into your own rule.

## 4. Wayland + Hyprland

What the installer does:

- [ ] Copies the shader to `~/.config/hypr/shaders/crt.frag`
- [ ] Tries to apply it live via `hyprctl` (if available)
- [ ] Prints the permanent config line

**Hyprland screen shaders affect the WHOLE screen, not just the terminal.**

Try it live:

```bash
hyprctl keyword decoration:screen_shader ~/.config/hypr/shaders/crt.frag
```

Make it permanent — add to `~/.config/hypr/hyprland.conf`:

```ini
decoration {
    screen_shader = ~/.config/hypr/shaders/crt.frag
}
```

## 5. Verify It Works

**X11**: open any terminal (Alacritty, kitty, foot, ...).

```
# Expected: the terminal window curves at the corners, shows faint horizontal
# scanlines and a vignette. Non-terminal windows (browser, file manager) are
# unaffected.
```

**Wayland/Hyprland**: look at the whole screen.

```
# Expected: the entire screen curves with scanlines and a vignette.
```

Confirm a terminal's window class is matched (X11):

```bash
xprop WM_CLASS    # then click your terminal window
# Expected: WM_CLASS(STRING) = "alacritty", "Alacritty"
# The second value (class_g) must appear in the picom rule.
```

## 6. Disable / Uninstall

**X11** — remove the rule block and restart picom:

```bash
# Delete the lines from "# === crt-compositor" through the closing "];" in:
#   ~/.config/picom.conf
pkill picom; picom --config ~/.config/picom.conf &
```

**Wayland/Hyprland** — unset the screen shader:

```bash
hyprctl keyword decoration:screen_shader "[[EMPTY]]"
# and remove the screen_shader line from ~/.config/hypr/hyprland.conf
```

Remove the shader files (optional):

```bash
rm -f ~/.config/picom/shaders/crt.glsl ~/.config/hypr/shaders/crt.frag
```

## 7. Troubleshooting

**Problem**: `==> Session type: unknown` and nothing installs.
**Solution**: `XDG_SESSION_TYPE`, `WAYLAND_DISPLAY` and `DISPLAY` are all empty —
you're likely in a TTY or over SSH. Run the installer from inside your graphical session.

**Problem**: picom won't start: "couldn't open shader file".
**Solution**: The path in `picom.conf` must be **absolute**. Confirm
`~/.config/picom/shaders/crt.glsl` exists and the rule points to the expanded path.

**Problem**: Shader compiles but the window is solid black.
**Solution**: Your picom build may be too old for `window-shader-fg-rule` (needs the
GLX/EGL backend, picom 9+). Check `picom --version` and set `backend = "glx";` in
`picom.conf`.

**Problem**: Hyprland: `screen_shader` line ignored.
**Solution**: It must live inside the `decoration { }` block. Reload with
`hyprctl reload` and check `hyprctl getoption decoration:screen_shader`.

**Problem**: The effect is too strong / scanlines too dark.
**Solution**: Tune the constants in the shader — see
[TECHNICAL.md](TECHNICAL.md#extending-the-system).

**Problem**: My terminal isn't curved (X11) but others are.
**Solution**: Its window class isn't in the rule. Get it with `xprop WM_CLASS` and add
`|| class_g = '<YourClass>'` to the rule in `picom.conf`.

## 8. Next Steps

- [ ] Tune the CRT look (curvature, scanline intensity) in the shaders
- [ ] Add your terminal's window class to the picom rule if it isn't matched
- [ ] Read [TECHNICAL.md](TECHNICAL.md) to understand the shader interfaces
- [ ] If you use KWin/Sway, consider porting the shader to that compositor
