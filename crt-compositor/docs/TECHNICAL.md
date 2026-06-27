# Technical Documentation

How **crt-compositor** injects a CRT shader into the compositor's render pipeline, the
shader interfaces it uses, and how to extend it.

## Table of Contents

1. [Overview](#1-overview)
2. [Architecture](#2-architecture)
3. [X11: picom window-shader-fg-rule](#3-x11-picom-window-shader-fg-rule)
4. [Wayland: Hyprland screen_shader](#4-wayland-hyprland-screen_shader)
5. [Shader Interfaces](#5-shader-interfaces)
6. [The CRT Algorithm](#6-the-crt-algorithm)
7. [Installer Internals](#7-installer-internals)
8. [Extending the System](#8-extending-the-system)

---

## 1. Overview

A terminal emulator draws characters into a window. A **compositor** takes every
window's buffer and draws them onto the screen, usually via the GPU. Because the
compositor controls that final GPU pass, it can run a fragment shader over a window
(or the whole screen) — which is how we get a terminal-independent CRT effect.

| Component | Technology |
|-----------|------------|
| X11 compositor | picom (GLX/EGL backend, v9+) |
| Wayland compositor | Hyprland |
| Shader language | GLSL (`#version 330` for picom, GLES `precision` for Hyprland) |
| Installer | Bash (dual-mode local/remote) |

---

## 2. Architecture

```
                         ┌────────────────────────────────────────────┐
                         │              Terminal emulators              │
                         │   Alacritty │ kitty │ foot │ xterm │ st ...  │
                         └───────────────────────┬──────────────────────┘
                                                 │ window buffers
                                                 v
        X11 path                          ┌──────────────┐                Wayland path
   ┌──────────────────┐                   │  Compositor  │           ┌────────────────────┐
   │  picom            │  per-window       │  (GPU pass)  │  whole    │  Hyprland           │
   │  window-shader-   │ ─────────────────>│              │<──────────│  decoration:        │
   │  fg-rule          │  match WM_CLASS   │              │  screen   │  screen_shader      │
   └────────┬──────────┘                   └──────┬───────┘           └─────────┬──────────┘
            │ crt.glsl                             │                            │ crt.frag
            v                                      v                            v
   ┌──────────────────┐                   ┌──────────────┐           ┌────────────────────┐
   │ only terminal     │                   │  framebuffer │           │ ENTIRE screen       │
   │ windows curved    │                   │  -> display  │           │ curved (everything) │
   └──────────────────┘                   └──────────────┘           └────────────────────┘
```

Key difference: **picom applies per-window** (we restrict to terminal classes), while
**Hyprland applies to the whole screen** (no per-window hook exists in Hyprland).

---

## 3. X11: picom window-shader-fg-rule

picom (GLX/EGL backend) lets you attach a custom fragment shader to a window's
foreground via `window-shader-fg-rule`. Syntax:

```ini
window-shader-fg-rule = [
  "<absolute-shader-path> : <condition>"
];
```

- `<absolute-shader-path>` — picom needs an **absolute** path; the installer expands
  `$HOME` so the file contains a real path (e.g. `/home/<user>/.config/picom/shaders/crt.glsl`).
- `<condition>` — a picom matching expression. We match window class:
  `class_g = 'Alacritty' || class_g = 'kitty' || ...`. `class_g` is the *second*
  string of `WM_CLASS` (find it with `xprop WM_CLASS`).

picom calls the shader's `window_shader()` for each fragment of the matched window,
passing the window texture. Windows that don't match render normally.

---

## 4. Wayland: Hyprland screen_shader

Hyprland exposes one shader hook: `decoration:screen_shader`, a path to a GLSL
fragment shader applied to the **final composited screen**.

```ini
decoration {
    screen_shader = ~/.config/hypr/shaders/crt.frag
}
```

- Apply live: `hyprctl keyword decoration:screen_shader ~/.config/hypr/shaders/crt.frag`
- Clear live: `hyprctl keyword decoration:screen_shader "[[EMPTY]]"`
- Query: `hyprctl getoption decoration:screen_shader`

There is **no per-window** screen shader in Hyprland — the effect covers the whole
output, including the bar, wallpaper, and every window. This is an inherent limitation,
not a bug in this recipe.

---

## 5. Shader Interfaces

The two shaders implement the same look against two different host contracts.

### picom — `shaders/picom-crt.glsl`

```glsl
#version 330
in vec2 texcoord;          // fragment coords IN PIXELS
uniform sampler2D tex;      // the window texture
uniform float opacity;      // window opacity
vec4 window_shader();       // picom entry point; sample tex, return final color
```

picom samples in **pixel space**: the shader normalizes with `textureSize(tex,0)` and
samples back with `texture(tex, cuv * size)`. Out-of-curve fragments return
**transparent black** (`vec4(0)`), keeping window edges clean.

### Hyprland — `shaders/hyprland-crt.frag`

```glsl
precision mediump float;
varying vec2 v_texcoord;     // fragment coords NORMALIZED 0..1
uniform sampler2D tex;        // the screen texture
void main();                  // GLES entry point; write gl_FragColor
```

Hyprland works in **normalized** UV space and uses `texture2D`. Out-of-curve fragments
return **opaque black** (`vec4(...,1.0)`) because there's nothing behind the screen.

| Aspect | picom (`window_shader`) | Hyprland (`main`) |
|--------|--------------------------|--------------------|
| Coord space | pixels (`texcoord`) | normalized (`v_texcoord`) |
| Sampler call | `texture(tex, uv*size)` | `texture2D(tex, uv)` |
| Out-of-curve | transparent (`alpha 0`) | opaque black (`alpha 1`) |
| Output | `return c * opacity;` | `gl_FragColor = ...;` |
| Scanline height | from `textureSize` (exact) | hardcoded `1080.0` (tune it) |

---

## 6. The CRT Algorithm

Both shaders share the same passes:

1. **Curvature** — `curve(uv)` warps UVs outward so the screen bulges like a tube:
   ```glsl
   uv = uv * 2.0 - 1.0;
   uv *= 1.04;
   uv.x *= 1.0 + pow(abs(uv.y) / 4.0, 2.0);
   uv.y *= 1.0 + pow(abs(uv.x) / 3.5, 2.0);
   return uv * 0.5 + 0.5;
   ```
2. **Edge clip** — fragments warped outside `0..1` become black/transparent.
3. **Scanlines** — `sin(y * height * 1.6) * 0.08` subtracts a periodic darkening.
4. **Phosphor mask** (picom only) — `0.92 + 0.08 * sin(x * width * π)` simulates the
   column triad.
5. **Vignette** — `pow(16 * x * y * (1-x) * (1-y), 0.18)` darkens corners.
6. **Brightness** — `* 1.12` compensates for the darkening passes.

---

## 7. Installer Internals

`install.sh` is dual-mode and idempotent. Key helpers:

| Function | Purpose |
|----------|---------|
| `download(url, out)` | Fetch via `curl` **or** `wget`, whichever exists |
| `fetch(rel, dest)` | Copy from the local checkout if present, else `download` from `REPO_RAW` |
| `pm_install(pkg)` | Install via apt/dnf/yum/pacman/zypper (no brew — Linux only) |
| `ensure_cmd(cmd, pkg)` | Install `pkg` only if `cmd` is missing |
| `detect_session()` | `XDG_SESSION_TYPE`, then `WAYLAND_DISPLAY` / `DISPLAY` |
| `is_hyprland()` | `HYPRLAND_INSTANCE_SIGNATURE` or `hyprctl` present |

Dispatch logic:

```
Hyprland detected & not x11  -> install_hyprland   (whole-screen)
session == x11               -> install_picom      (per-window terminals)
session == wayland (no Hypr) -> unsupported (guidance)
otherwise                    -> unsupported (guidance)
```

The picom path **refuses to edit** a `picom.conf` that already contains a
`window-shader-fg-rule` — it prints the snippet so the user merges by hand, avoiding
corruption of an existing rule.

---

## 8. Extending the System

### Tune the CRT look

Edit the shared constants in both shader files:

| Constant | Effect | In code |
|----------|--------|---------|
| `1.04` (in `curve`) | overall zoom | `uv *= 1.04;` |
| `/ 4.0`, `/ 3.5` | curvature strength (X / Y) | inside `curve()` |
| `* 0.08` (scanline) | scanline darkness | `sin(...) * 0.08` |
| `1.6` (scanline) | scanline frequency | `sin(y * h * 1.6)` |
| `0.18` (vignette) | vignette falloff | `pow(vig, 0.18)` |
| `1.12` | global brightness | `col *= 1.12;` |
| `1080.0` (Hyprland only) | scanline density per display | set to your panel height |

### Add a terminal window class (X11)

Find the class with `xprop WM_CLASS`, then append to the rule in `~/.config/picom.conf`:

```ini
... || class_g = 'YourTerminalClass'"
```

### Port to another compositor (KWin, Sway, ...)

The GLSL math in `shaders/` is portable; only the host contract changes:

- **KWin (KDE)** — wrap the algorithm in a KWin OpenGL/QML effect; KWin doesn't read
  picom/Hyprland shader files. Use a `Shadertoy`-style effect or a custom
  `GLShader`-based effect plugin.
- **Sway / wlroots** — no stable per-window or screen shader hook today; a fork/patch
  or a Vulkan layer would be required.

Whatever the host, keep the pass order from [section 6](#6-the-crt-algorithm) and adapt
the entry point (coord space + sampler function) to match that compositor's interface,
mirroring the picom/Hyprland differences in [section 5](#5-shader-interfaces).
