# Technical Documentation

How Ghostty's `custom-shader` feature renders the CRT/glow effects, what each
GLSL shader does, how the `retro-theme` switcher edits the config and drives the
effect state machine, and how the Terminator color sync works.

## Table of Contents

1. [Overview](#1-overview)
2. [Architecture](#2-architecture)
3. [Components](#3-components)
4. [How custom-shader Works in Ghostty](#4-how-custom-shader-works-in-ghostty)
5. [crt.glsl — The CRT Shader](#5-crtglsl--the-crt-shader)
6. [glow.glsl — The Neon Glow Shader](#6-glowglsl--the-neon-glow-shader)
7. [The retro-theme Switcher](#7-the-retro-theme-switcher)
8. [The fx State Machine](#8-the-fx-state-machine)
9. [Terminator Color Sync](#9-terminator-color-sync)
10. [zsh Completion](#10-zsh-completion)
11. [Extending the System](#11-extending-the-system)

---

## 1. Overview

Ghostty supports **Shadertoy-style GLSL fragment shaders** via the
`custom-shader` config key. This recipe ships two such shaders (a CRT look and a
neon-glow look) plus a `retro-theme` command that edits the Ghostty config to
switch the active theme and shader, and mirrors the theme's color palette into
Terminator.

| Component | Technology |
|-----------|------------|
| Screen effects | GLSL fragment shaders (Shadertoy `mainImage` convention) |
| Effect host | Ghostty `custom-shader` + `custom-shader-animation` |
| Switcher | bash script (`retro-theme`) editing `~/.config/ghostty/config` via `sed` |
| Theme source | `ghostty +list-themes` / snap theme files |
| Terminator sync | `awk` rewrite of `~/.config/terminator/config` |
| Shell integration | zsh alias `rt` + `compdef` completion |

---

## 2. Architecture

```
                         ┌──────────────────────────┐
        user runs  ────► │       retro-theme        │
        rt "Cyberpunk"   │       (bin/retro-theme)  │
        rt fx glow       └────────────┬─────────────┘
                                      │
                ┌─────────────────────┼──────────────────────────┐
                │ apply_theme()        │ set_fx()                  │
                │ sed: theme =         │ sed: custom-shader =      │
                ▼                      ▼                           │
   ┌───────────────────────────────────────────┐                 │
   │        ~/.config/ghostty/config            │                 │
   │   theme = Cyberpunk                         │                 │
   │   custom-shader = shaders/glow.glsl         │─── read by ───┐ │
   │   custom-shader-animation = true            │               │ │
   └───────────────────────────────────────────┘               │ │
                │                                                 ▼ │
                │ sync_terminator()                  ┌──────────────────────┐
                │ awk rewrite                         │       Ghostty        │
                ▼                                     │  loads theme + GLSL  │
   ┌───────────────────────────────────────────┐    │  shader on the GPU;  │
   │     ~/.config/terminator/config            │    │  Ctrl+Shift+, reloads│
   │   [[default]]                               │    └──────────────────────┘
   │     foreground_color = "#..."               │
   │     background_color = "#..."               │     (colors only; the CRT/
   │     palette = "#..:#..: ... (16 colors)"    │      glow shaders cannot be
   └───────────────────────────────────────────┘      reproduced in Terminator)
```

One command writes to **two** config files: Ghostty (theme + shader) and, if
present, Terminator (palette only).

---

## 3. Components

```
ghostty-retro-theme/
├── install.sh           # Idempotent installer; backs up existing config
├── config               # Ghostty config template (font, theme, shader, cursor)
├── bin/
│   └── retro-theme      # Switcher: apply_theme / set_fx / sync_terminator
├── shaders/
│   ├── crt.glsl         # CRT: curvature, scanlines, vignette, glow, aberration
│   └── glow.glsl        # Neon bloom, no curvature/scanlines
└── zshrc-snippet.zsh    # `rt` alias + zsh completion (compdef)
```

---

## 4. How custom-shader Works in Ghostty

Ghostty renders the terminal grid to a texture, then runs your fragment shader as
a **post-process pass** over that texture before presenting the frame. The shader
follows the **Shadertoy** convention, which means you implement:

```glsl
void mainImage(out vec4 fragColor, in vec2 fragCoord);
```

Ghostty provides the standard Shadertoy uniforms:

| Uniform | Type | Meaning |
|---------|------|---------|
| `iChannel0` | `sampler2D` | The rendered terminal contents (the input image) |
| `iResolution` | `vec3` | Output resolution in pixels (`.xy` = width, height) |
| `iTime` | `float` | Seconds since start (for animation) |
| `fragCoord` | `vec2` | Pixel coordinate of the current fragment |
| `fragColor` | `vec4` | The output color you write |

Configuration keys (in `~/.config/ghostty/config`):

```
custom-shader = shaders/crt.glsl     # path relative to the config directory
custom-shader-animation = true       # advance iTime so animated shaders run
```

The shader path is **relative to `~/.config/ghostty/`**, which is why the files
live in `~/.config/ghostty/shaders/`. Changes take effect on config reload
(**Ctrl+Shift+,**) or in a new window.

---

## 5. crt.glsl — The CRT Shader

A single `mainImage` pass that turns the flat terminal texture into a curved CRT
tube. Pipeline, in order:

1. **`curve(uv)`** — remaps screen UVs to simulate tube curvature. It recenters
   UVs to `[-1, 1]`, scales slightly (`*= 1.05`), then bulges each axis as a
   function of the other (`uv.x *= 1.0 + pow(abs(uv.y)/4.0, 2.0)` and the
   symmetric `uv.y`), then maps back to `[0, 1]`. Larger divisors → flatter
   screen.

2. **Border masking** — any curved coordinate that falls outside `[0, 1]` is the
   area "off the tube" and is painted solid black, producing the rounded CRT
   bezel.

3. **Chromatic aberration** — samples the red channel slightly to the right and
   blue slightly to the left of the texel (`ca = 0.0012`), giving color fringing
   toward the edges.

4. **Scanlines** — subtracts a sine wave along Y scaled by the vertical
   resolution (`sin(cuv.y * iResolution.y * 1.6) * 0.08`) so alternating rows
   darken.

5. **Phosphor mask** — a per-column sine (`0.92 + 0.08 * sin(cuv.x * iResolution.x * π)`)
   modulates brightness to mimic the RGB phosphor stripe pattern.

6. **Vignette** — `pow(16 * x*y*(1-x)*(1-y), 0.18)` darkens the corners.

7. **Brightness lift** — `col *= 1.12` compensates for the darkening above.

Tuning cheat-sheet:

| Effect | Constant | Direction |
|--------|----------|-----------|
| Curvature | `/ 4.0`, `/ 3.5` in `curve()` | larger = flatter |
| Scanline depth | `* 0.08` | smaller = subtler |
| Phosphor mask | `0.92 + 0.08` | raise base toward 1.0 = subtler |
| Aberration | `ca = 0.0012` | smaller = less fringing |
| Vignette | `pow(vig, 0.18)` | smaller exponent = darker corners |
| Brightness | `col *= 1.12` | overall gain |

---

## 6. glow.glsl — The Neon Glow Shader

A flat (no curvature, no scanlines) shader that adds a futuristic neon bloom.
Pipeline:

1. **Base sample + chromatic aberration** — same edge fringing as the CRT but
   subtler (`ca = 0.0008`).

2. **Bloom kernel** — a 7×7 box of samples (`x,y ∈ [-3, 3]`) around the current
   pixel, offset in texture space (`/ iResolution.xy * 2.5`). Each sample is
   weighted by `1.0 / (1.0 + (x² + y²))` (a cheap distance falloff), summed, and
   normalized by the total weight — i.e. a weighted blur.

3. **Halo add** — only the bright part of the blur is added back:
   `col += pow(bloom, vec3(1.5)) * 0.45`. The `pow(.., 1.5)` suppresses dark
   areas so only bright glyphs bloom; `0.45` is the glow strength.

4. **Soft vignette** + slight brightness lift (`col *= 1.05`).

Tuning: bloom radius via the kernel bounds and the `2.5` offset multiplier; glow
strength via `* 0.45`; how selective the halo is via the `pow(.., 1.5)` exponent.

> The kernel is 49 texture samples per pixel — heavier than the CRT shader but
> still trivial for a modern GPU at terminal resolutions.

---

## 7. The retro-theme Switcher

`bin/retro-theme` edits `~/.config/ghostty/config` in place. It defines three
curated theme groups as bash arrays — `RETRO`, `FUTURO`, `PAPEL` (paper) — and
dispatches on its arguments:

| Invocation | Handler | Action |
|------------|---------|--------|
| `retro-theme` | interactive menu | Prints the three groups, reads a number, applies it |
| `retro-theme "<name>"` | `apply_theme` | Sets `theme = <name>` |
| `retro-theme -l` | — | `ghostty +list-themes` (strips ` (resources)`) |
| `retro-theme fx <mode>` | `set_fx` | Sets/removes `custom-shader =` |
| `retro-theme fx` | `current_fx` | Reports the active effect |

`apply_theme()` rewrites the theme line with `sed` if one exists, otherwise
appends it:

```bash
if grep -qE '^[[:space:]]*theme[[:space:]]*=' "$CFG"; then
  sed -i -E "s|^[[:space:]]*theme[[:space:]]*=.*|theme = ${theme}|" "$CFG"
else
  printf '\ntheme = %s\n' "$theme" >> "$CFG"
fi
```

It then calls `sync_terminator "$theme"` and prints the reload hint. Every change
requires a Ghostty reload (Ctrl+Shift+,) to take effect.

---

## 8. The fx State Machine

The screen effect has three states — `crt`, `glow`, `off` — represented entirely
by the `custom-shader` line in the config:

```
                 set_fx "crt"            set_fx "glow"
       ┌──────────────────────────┐ ┌──────────────────────────┐
       │                          │ │                          │
       ▼                          │ ▼                          │
  ┌─────────┐  set_fx "glow"  ┌─────────┐  set_fx "off"   ┌─────────┐
  │   crt   │ ───────────────►│  glow   │ ───────────────►│   off   │
  │ shader= │                 │ shader= │                 │ (no     │
  │ crt.glsl│ ◄───────────────│glow.glsl│ ◄───────────────│ shader  │
  └─────────┘  set_fx "crt"   └─────────┘  set_fx "crt"   │  line)  │
       ▲                                  set_fx "glow"   └─────────┘
       └──────────────────────────────────────────────────────┘
                            set_fx "crt"
```

`set_fx()` first deletes **any** existing `custom-shader =` line (commented or
not), then appends the new one — or nothing, for `off`:

```bash
sed -i -E '/^[[:space:]]*#?[[:space:]]*custom-shader[[:space:]]*=/d' "$CFG"
case "$mode" in
  crt)  printf 'custom-shader = shaders/crt.glsl\n'  >> "$CFG" ;;
  glow) printf 'custom-shader = shaders/glow.glsl\n' >> "$CFG" ;;
  off)  : ;;   # no line = no effect
  *)    echo "invalid fx. Use: crt | glow | off" >&2; exit 1 ;;
esac
```

`current_fx()` reads the state back by matching the filename in the
`custom-shader` line (`*crt.glsl*` → `crt`, `*glow.glsl*` → `glow`, else `off`).
Note that `set_fx` deliberately leaves `custom-shader-animation` untouched, so
animation stays enabled across effect switches.

---

## 9. Terminator Color Sync

Because the CRT/glow effects are GPU shaders exclusive to Ghostty, the only thing
that can be shared with Terminator is the **color palette**. `sync_terminator()`
reads the chosen theme file and rewrites Terminator's `[[default]]` profile.

**Read** — from the Ghostty theme file
(`/snap/ghostty/current/share/ghostty/themes/<name>`), it pulls `foreground`,
`background`, `cursor-color`, and the 16 `palette = N=...` entries, assembling a
colon-separated 16-color palette string.

**Write** — an `awk` program rewrites `~/.config/terminator/config`:

- It scans for the `[[default]]` profile block.
- Inside that block it **drops** any existing `use_theme_colors`,
  `foreground_color`, `background_color`, `cursor_color`, and `palette` lines.
- When it reaches the end of the block (next `[[...]]` or top-level `[...]`
  section, or EOF) it **inserts** the new keys, with `use_theme_colors = False`
  so Terminator honors the explicit colors.
- The result is written to a temp file (`${TCFG}.tmp.$$`) and atomically
  `mv`-d over the original.

```
Ghostty theme file ──read──► fg / bg / cursor / palette[0..15]
                                   │
                                   ▼  awk (rewrite [[default]] block)
~/.config/terminator/config ──────────────► same file, new colors
                                   │
                                   ▼
                       open a NEW Terminator window to see them
```

If the theme file or the Terminator config (with a `[[default]]` block) is
absent, the function returns early and sync is silently skipped — Ghostty is
still themed normally.

---

## 10. zsh Completion

`zshrc-snippet.zsh` defines the `rt` alias and a completion function
`_retro_theme`, bound to both commands via `compdef _retro_theme retro-theme rt`.

- At argument position 1 (`CURRENT == 2`): offers `fx` and `-l`, then the live
  list of Ghostty themes from `ghostty +list-themes` (with ` (resources)`
  stripped via `sed`).
- At argument position 2 when the first word is `fx`: offers `crt`, `glow`, `off`
  with descriptions.

It runs `autoload -Uz compinit && compinit -C` defensively so completion works
even if the user's framework hasn't initialized it. `_describe` provides the
grouped, described candidate lists.

---

## 11. Extending the System

### Add a theme to a group

Edit the relevant array in `bin/retro-theme` — `RETRO`, `FUTURO`, or `PAPEL`.
Add the exact Ghostty theme name (see `rt -l`) as a new array element. The
interactive menu numbering, the direct-apply path, and Terminator sync all pick
it up automatically:

```bash
FUTURO=(
  "Cyberpunk"
  "Synthwave"
  "Aurora"        # ← new entry; must match a name from `ghostty +list-themes`
  ...
)
```

### Add a new theme group

1. Define a new array (e.g. `OCEAN=( "..." "..." )`).
2. Append it to the `ALL=(...)` line so its entries get menu indices.
3. Add an `echo "== OCEAN =="` header plus the printf loop in the interactive
   menu, computing its offset the same way `o2`/`o3` are computed.

### Add a new shader effect

1. Drop `myfx.glsl` into `shaders/` (and the installer copies it to
   `~/.config/ghostty/shaders/`). It must implement Shadertoy `mainImage` and use
   `iChannel0` / `iResolution` / `iTime`.
2. Teach the fx state machine about it in `bin/retro-theme`:
   - Add a `case` arm in `set_fx()`:
     `myfx) printf 'custom-shader = shaders/myfx.glsl\n' >> "$CFG"; echo "Effect: myfx" ;;`
   - Add a match in `current_fx()`: `*myfx.glsl*) echo "myfx" ;;`
3. Add it to the completion in `zshrc-snippet.zsh` (`fx=(... 'myfx:my effect')`).

### Point sync at a non-snap Ghostty

If Ghostty isn't installed via snap, edit `THEMES_DIR` near the top of
`bin/retro-theme` to your install's themes directory (where the per-theme files
with `foreground`/`background`/`palette = N=` live). The rest of the sync is
path-agnostic.
