# Technical Documentation

Detailed architecture, components, data flow, and extension points for
**retro-theme** — the terminal-agnostic theme & screen-effect switcher.

## Table of Contents

1. [Overview](#1-overview)
2. [Architecture](#2-architecture)
3. [Components](#3-components)
4. [Theme File Format](#4-theme-file-format)
5. [Terminal Detection](#5-terminal-detection)
6. [Data Flow](#6-data-flow)
7. [Per-Terminal Adapters](#7-per-terminal-adapters)
8. [Screen Effects](#8-screen-effects)
9. [Installer](#9-installer)
10. [Extending the System](#10-extending-the-system)

---

## 1. Overview

`retro-theme` is one Bash script (`bin/retro-theme`) plus a folder of palette
files (`themes/*.conf`) and the screen-effect shaders: GLSL for Ghostty
(`shaders/{crt,glow}.glsl`) and HLSL for Windows Terminal
(`shaders/{crt,glow}.hlsl`).

The flow is always the same: **detect** which terminal you're in → **read** a
palette file → **dispatch** to the adapter for that terminal → the adapter
writes the colors using the terminal's *own* native config mechanism. Screen
effects (CRT/glow) are applied separately and only where the terminal supports
them.

| Component | Technology | File |
|-----------|------------|------|
| Engine + adapters | Bash 5 | `bin/retro-theme` |
| Palettes | `key=value` text | `themes/*.conf` (24 themes) |
| Screen effects (Ghostty) | GLSL (Shadertoy-style) | `shaders/crt.glsl`, `shaders/glow.glsl` |
| Screen effects (Windows Terminal) | HLSL (WT shader interface) | `shaders/crt.hlsl`, `shaders/glow.hlsl` |
| Shell integration | zsh alias + completion | `zshrc-snippet.zsh` |
| Installer | Bash + curl | `install.sh` |

Design constraints baked into the code:

- **No terminal is required.** Palettes are self-contained text files, so the
  tool runs even without Ghostty installed.
- **Native config per terminal.** Each adapter speaks the target terminal's
  config language (Ghostty `palette =`, kitty `colorNN`, Alacritty TOML,
  GNOME `gsettings`, Windows Terminal JSON, etc.).
- **Idempotent writes.** Adapters strip their previous output before re-writing,
  or use `include`/`import` markers guarded by `grep -qF`.

---

## 2. Architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│                          bin/retro-theme (Bash)                        │
│                                                                        │
│  ┌──────────────┐   ┌─────────────────┐   ┌────────────────────────┐  │
│  │ asset locate │   │  CLI dispatch   │   │   helpers              │  │
│  │ THEMES_DIR   │   │  --detect / -l  │   │   tget / theme_file    │  │
│  │ SHADERS_DIR  │   │  fx / <name>    │   │   palette_of / hex*    │  │
│  └──────────────┘   └─────────────────┘   └────────────────────────┘  │
│         │                    │                       │                 │
│         v                    v                       v                 │
│  ┌──────────────┐   ┌─────────────────┐   ┌────────────────────────┐  │
│  │ detect_      │   │ apply_theme_cli │   │   set_fx_ghostty       │  │
│  │ terminals()  │──>│ (build targets) │   │   (CRT/glow shader)    │  │
│  └──────────────┘   └─────────────────┘   └────────────────────────┘  │
│                              │                                          │
│                              v                                          │
│                     ┌──────────────────┐                               │
│                     │   apply_to()     │  case dispatch on term id     │
│                     └──────────────────┘                               │
└──────────────────────────────┬─────────────────────────────────────────┘
                                │
   ┌──────────┬──────────┬──────┴─────┬──────────┬──────────┬──────────┐
   v          v          v            v          v          v          v
┌────────┐┌─────────┐┌──────────┐┌──────────┐┌────────┐┌──────────┐┌────────┐
│ghostty ││windows_t││ gnome_t  ││terminator││ kitty  ││alacritty ││wezterm │ …iterm2
│config  ││settings ││ gsettings││  config  ││.conf + ││.toml +   ││colors/ │  Dynamic
│+shader ││.json/jq ││  (dconf) ││  (awk)   ││include ││import    ││*.toml  │  Profile
└────────┘└─────────┘└──────────┘└──────────┘└────────┘└──────────┘└────────┘
```

---

## 3. Components

### Asset location

At startup the script resolves two directories so it works both from a checkout
and from an installed layout:

```
THEMES_DIR  ← first existing of:  $RETRO_THEME_HOME
                                  $SELF/../themes          (checkout)
                                  ~/.config/retro-theme/themes  (installed)
SHADERS_DIR ← first existing of:  $SELF/../shaders         (checkout)
                                  ~/.config/ghostty/shaders     (installed)
```

If no themes directory is found, the script exits with
`themes dir not found (set RETRO_THEME_HOME)`.

### Helper functions

| Function | Signature | Purpose |
|----------|-----------|---------|
| `tget` | `tget <file> <key>` | Read a single `key=value` from a theme file (first match) |
| `theme_file` | `theme_file <name-or-slug>` | Resolve a display name **or** `.conf` basename to a path |
| `palette_of` | `palette_of <file>` | Echo `color0 … color15` space-separated |
| `hexr/hexg/hexb` | `hex* <#rrggbb>` | Convert a hex channel to a `0..1` float (for iTerm2) |
| `detect_terminals` | `detect_terminals` | Print one terminal id per detected terminal |
| `apply_to` | `apply_to <theme-file> <term-id>` | Set `$TF` and dispatch to the right adapter |
| `apply_theme_cli` | `apply_theme_cli <theme-file> <scope>` | Build the target list, apply, then set the Ghostty effect |
| `set_fx_ghostty` | `set_fx_ghostty crt\|glow\|off` | Rewrite the `custom-shader` line in the Ghostty config |
| `set_fx_wt` | `set_fx_wt crt\|glow\|off` | Install the HLSL shader + set `pixelShaderPath` in Windows Terminal `settings.json` (falls back to `retroTerminalEffect` for `crt`) |
| `set_default_wt` | `set_default_wt [name]` | Set Windows Terminal `defaultProfile` to a profile (defaults to `$WSL_DISTRO_NAME`, else first WSL profile) |

`$TF` is the convention every adapter relies on: `apply_to` sets it to the
resolved theme-file path, then calls `apply_<terminal>`, which reads its values
via `tget "$TF" <key>`.

### CLI surface

| Invocation | Handler |
|------------|---------|
| `retro-theme --detect` | prints `Detected: <ids|none>` |
| `retro-theme --set-default [name]` | `set_default_wt` — set the Windows Terminal default profile |
| `retro-theme -l` | lists `name [group]` for every `.conf` |
| `retro-theme fx crt\|glow\|off` | sets effect on detected terminals (Ghostty + Windows Terminal) |
| `retro-theme <name> [--all]` | `apply_theme_cli` |
| `retro-theme` (no args) | interactive numbered menu |

---

## 4. Theme File Format

A theme is a flat `key=value` text file in `themes/<slug>.conf`. The `<slug>`
(the filename without `.conf`) doubles as a valid theme identifier on the CLI.

```ini
name=Tokyo Night          # display name (used by menus and -l)
group=futuristic          # one of: retro | futuristic | paper
fx=glow                   # default effect: crt | glow | off
background=#1a1b26         # hex #rrggbb
foreground=#c0caf5
cursor=#c0caf5
color0=#15161e            # the 16 ANSI colors, color0 … color15
color1=#f7768e
# … color2 through color14 …
color15=#c0caf5
```

| Key | Required | Meaning |
|-----|:--------:|---------|
| `name` | yes | Human-readable name; matched by `theme_file` and shown in lists |
| `group` | yes | Category label (`retro`, `futuristic`, `paper`) shown in `-l` |
| `fx` | yes | Default screen effect used on apply for Ghostty / Windows Terminal |
| `background` / `foreground` / `cursor` | yes | Base colors, hex `#rrggbb` |
| `color0` … `color15` | yes | The 16-color ANSI palette, hex `#rrggbb` |

The 24 bundled themes (2 `retro`, 16 `futuristic`, 6 `paper`):

| Name | Slug | Group | `fx` |
|------|------|-------|------|
| Retro Green | `retro-green` | retro | crt |
| Amber CRT | `amber` | retro | crt |
| Ayu Dark | `ayu-dark` | futuristic | glow |
| Catppuccin Mocha | `catppuccin-mocha` | futuristic | glow |
| Cyberpunk Neon | `cyberpunk-neon` | futuristic | glow |
| Dracula | `dracula` | futuristic | glow |
| Everforest Dark | `everforest-dark` | futuristic | off |
| Gruvbox Dark | `gruvbox-dark` | futuristic | off |
| Gruvbox Material Dark | `gruvbox-material-dark` | futuristic | off |
| Kanagawa | `kanagawa` | futuristic | glow |
| Monokai | `monokai` | futuristic | glow |
| Night Owl | `night-owl` | futuristic | glow |
| Nord | `nord` | futuristic | glow |
| One Dark | `one-dark` | futuristic | glow |
| Rosé Pine | `rose-pine` | futuristic | glow |
| Solarized Dark | `solarized-dark` | futuristic | off |
| SynthWave '84 | `synthwave-84` | futuristic | glow |
| Tokyo Night | `tokyo-night` | futuristic | glow |
| Ayu Light | `ayu-light` | paper | off |
| Catppuccin Latte | `catppuccin-latte` | paper | off |
| GitHub Light | `github-light` | paper | off |
| Gruvbox Light | `gruvbox-light` | paper | off |
| Rosé Pine Dawn | `rose-pine-dawn` | paper | off |
| Solarized Light | `solarized-light` | paper | off |

---

## 5. Terminal Detection

`detect_terminals()` inspects environment variables and prints one id per match
(so multiplexed setups can match several). Ids are the keys used everywhere else.

| Terminal id | Detected when |
|-------------|---------------|
| `ghostty` | `TERM_PROGRAM=ghostty` **or** `TERM=xterm-ghostty` |
| `windows-terminal` | `WT_SESSION` is non-empty **or** `microsoft`/`wsl` in `/proc/version` (any WSL session) |
| `gnome-terminal` | `GNOME_TERMINAL_SCREEN` is non-empty |
| `terminator` | `TERMINATOR_UUID` is non-empty |
| `kitty` | `KITTY_WINDOW_ID` non-empty **or** `TERM=xterm-kitty` |
| `alacritty` | `ALACRITTY_WINDOW_ID` / `ALACRITTY_SOCKET` non-empty **or** `TERM=alacritty` |
| `wezterm` | `WEZTERM_PANE` non-empty **or** `TERM_PROGRAM=WezTerm` |
| `iterm2` | `TERM_PROGRAM=iTerm.app` |

`--detect` prints `Detected: none` when nothing matches. The `--all` scope
bypasses detection entirely and targets the full id list.

---

## 6. Data Flow

Applying a theme (`retro-theme <name> [--all]`):

```
1. theme_file <name|slug>        → resolve to themes/<slug>.conf  (else exit)
2. apply_theme_cli(tf, scope)
     ├─ scope == --all ?  targets = [all 8 ids]
     │                     else   targets = detect_terminals()
     │                            (empty → warn + exit 1)
     ├─ FX_MODE = $FX_MODE  or  tget(tf, fx)        # theme's default effect
     ├─ for each target:  apply_to(tf, id)
     │                      └─ TF=tf; case id → apply_<terminal>()
     └─ if "ghostty" in targets: set_fx_ghostty(FX_MODE)
```

Setting an effect (`retro-theme fx crt|glow|off`):

```
1. validate mode ∈ {crt, glow, off}     (else usage error)
2. export FX_MODE=mode
3. for each detected terminal:
     ghostty          → set_fx_ghostty(mode)            # rewrite custom-shader (.glsl)
     windows-terminal → set_fx_wt(mode)                 # install .hlsl + set pixelShaderPath
     others           → warn: screen effects not supported (colors only)
```

`set_fx_wt` and the Windows Terminal theme adapter share the same logic: for a
`crt`/`glow` mode they copy `$SHADERS_DIR/<mode>.hlsl` into the WT `LocalState`
folder and point `pixelShaderPath` at it (via `wslpath -w`); if the `.hlsl` or
`wslpath` is unavailable, `crt` falls back to `retroTerminalEffect = true` and
`glow` is a no-op. `off` deletes `pixelShaderPath` and clears `retroTerminalEffect`.
When applying a theme, the effect comes from `FX_MODE` (the theme's `fx=` unless
overridden), so the effect is decided **at theme-apply time**.

---

## 7. Per-Terminal Adapters

Each adapter is an `apply_<terminal>` function that reads `$TF` and writes the
target's native config. All are idempotent.

### `apply_ghostty`
- File: `~/.config/ghostty/config`.
- Deletes existing `theme`/`background`/`foreground`/`cursor-color`/`palette`
  lines, then appends `background =`, `foreground =`, `cursor-color =` and
  `palette = N=#rrggbb` for `N` in `0..15`.
- Reload: `Ctrl+Shift+,`.

### `apply_windows_terminal`
- Requires `jq` (warns and returns if missing).
- Finds `settings.json` under
  `/mnt/c/Users/*/AppData/Local/Packages/Microsoft.WindowsTerminal*/LocalState/`
  or the unpackaged `.../Microsoft/Windows Terminal/` path.
- Builds a color **scheme** object with `jq -n`, then patches the file: replaces
  any same-named scheme and sets `profiles.defaults.colorScheme`.
- Screen effect (when `FX_MODE` is `crt`/`glow`): copies
  `$SHADERS_DIR/<mode>.hlsl` to `<LocalState>/retro-shader.hlsl` and sets
  `profiles.defaults.experimental.pixelShaderPath` to the Windows path
  (`wslpath -w`). This produces the same rich CRT/glow effect as Ghostty. If the
  `.hlsl` or `wslpath` is missing, `crt` falls back to
  `experimental.retroTerminalEffect = true`. When no shader path is set, the
  adapter deletes `pixelShaderPath`.

### `apply_gnome_terminal`
- Requires `gsettings`.
- Reads the default profile UUID from
  `org.gnome.Terminal.ProfilesList default`, then sets `use-theme-colors false`,
  `background-color`, `foreground-color`, the 16-entry `palette`, and the cursor
  color on that profile via dconf.

### `apply_terminator`
- File: `~/.config/terminator/config` (skips with a warning if absent).
- Uses `awk` to rewrite the `[[default]]` profile block in place: sets
  `use_theme_colors = False`, `foreground_color`, `background_color`,
  `cursor_color`, and a `:`-joined 16-color `palette`.

### `apply_kitty`
- Writes `~/.config/kitty/retro-theme.conf` (`background`, `foreground`,
  `cursor`, `color0..15`) and ensures `include retro-theme.conf` is in
  `kitty.conf`.
- Reload: `Ctrl+Shift+F5`.

### `apply_alacritty`
- Writes `~/.config/alacritty/retro-theme.toml` (`[colors.primary]`,
  `[colors.cursor]`, `[colors.normal]`, `[colors.bright]`) and prepends an
  `import = ["~/.config/alacritty/retro-theme.toml"]` line to `alacritty.toml`.

### `apply_wezterm`
- Writes `~/.config/wezterm/colors/<slug>.toml` with a `[colors]` table
  (`background`, `foreground`, `cursor_bg`, `cursor_border`, `ansi`, `brights`).
- The user must set `color_scheme = "<slug>"` in their `wezterm.lua`.

### `apply_iterm2` (macOS)
- Writes a Dynamic Profile JSON to
  `~/Library/Application Support/iTerm2/DynamicProfiles/retro-theme.json`.
- Colors are converted to iTerm2's `0..1` float components via `hexr/hexg/hexb`.
- Warns and returns if the profile directory can't be created (i.e. not macOS).

| Adapter | Output | Idempotency mechanism |
|---------|--------|-----------------------|
| ghostty | `config` | `sed` deletes prior keys before append |
| windows-terminal | `settings.json` | `jq` replaces same-named scheme |
| gnome-terminal | dconf | `gsettings set` (overwrite) |
| terminator | `config` | `awk` rewrites `[[default]]` block |
| kitty | `retro-theme.conf` | full rewrite + guarded `include` |
| alacritty | `retro-theme.toml` | full rewrite + guarded `import` |
| wezterm | `colors/<slug>.toml` | full rewrite per slug |
| iterm2 | `retro-theme.json` | full rewrite (fixed filename) |

---

## 8. Screen Effects

Effects exist only on terminals with native GPU/effect support.

### Ghostty (GLSL shaders)

`set_fx_ghostty` deletes the existing `custom-shader` line and appends one
pointing at `$SHADERS_DIR/crt.glsl` or `glow.glsl` (or nothing for `off`).

- **`shaders/crt.glsl`** — screen curvature (`curve()`), scanlines, a phosphor
  column mask, vignette, subtle chromatic aberration, and a brightness boost.
  Pixels outside the curved screen render black (tube border).
- **`shaders/glow.glsl`** — no curvature/scanlines; a 7×7 weighted bloom for a
  neon halo, light chromatic aberration, and a soft vignette.

Both are Shadertoy-style: `mainImage(out vec4 fragColor, in vec2 fragCoord)`
sampling `iChannel0` (terminal contents) with `iResolution`/`iTime` available.

### Windows Terminal (HLSL shaders)

Windows Terminal supports a custom pixel shader via
`profiles.defaults.experimental.pixelShaderPath`. Both `set_fx_wt` and
`apply_windows_terminal` copy the matching `$SHADERS_DIR/<mode>.hlsl` into the WT
`LocalState` folder (as `retro-shader.hlsl`) and set `pixelShaderPath` to its
Windows path (computed with `wslpath -w`, e.g. `C:\...\retro-shader.hlsl`). This
yields the **same CRT/glow look as Ghostty**.

- **`shaders/crt.hlsl`** — barrel `curve()`, scanlines, phosphor column mask,
  vignette, chromatic aberration, brightness lift; black outside the curved
  screen.
- **`shaders/glow.hlsl`** — 7×7 weighted bloom (neon halo), faint chromatic
  aberration, soft vignette.

The HLSL files use the Windows Terminal shader interface (not Shadertoy):

```hlsl
Texture2D    shaderTexture;
SamplerState samplerState;
cbuffer PixelShaderSettings {
    float  Time;
    float  Scale;
    float2 Resolution;
    float4 Background;
};
float4 main(float4 pos : SV_POSITION, float2 tex : TEXCOORD) : SV_TARGET { ... }
```

`shaderTexture`/`samplerState` sample the terminal contents; `Time`/`Resolution`
drive the animated/size-aware effects.

**Fallback:** if the `.hlsl` file or `wslpath` is unavailable, `crt` switches on
the built-in `experimental.retroTerminalEffect` instead (and `glow` is a no-op).
`off` removes `pixelShaderPath` and clears `retroTerminalEffect`.

### Setting the default profile

`set_default_wt [name]` (CLI: `--set-default`) sets WT's `defaultProfile`. It
resolves a profile GUID by matching `name` (case-insensitive) against the profile
list; with no name it defaults to `$WSL_DISTRO_NAME`, falling back to the first
profile whose `source` matches `Wsl`. Patches `settings.json` with `jq` and asks
you to reopen Windows Terminal.

### Everything else

No screen-effect support. `fx` emits
`screen effects not supported (colors only)`.

---

## 9. Installer

`install.sh` works from a checkout (`cp` from `$SRC`) or piped via curl
(downloads each asset from `REPO_RAW`). Steps:

1. Install `bin/retro-theme` → `~/.local/bin/retro-theme` (chmod +x).
2. Install all 24 themes → `~/.config/retro-theme/themes/`.
3. Install shaders → `~/.config/ghostty/shaders/`: `crt.glsl` + `glow.glsl`
   (Ghostty) and `crt.hlsl` + `glow.hlsl` (Windows Terminal).
4. If `ghostty` is on `PATH`: back up any existing `~/.config/ghostty/config`
   (timestamped `.bak`) and install the sample `config`.
5. Append the `rt` alias + zsh completion to `~/.zshrc` (guarded by a marker so
   it's added at most once).
6. Warn if `~/.local/bin` is not on `PATH`.
7. Warn if `jq` is missing (needed for Windows Terminal).

The installer is idempotent: re-running it overwrites assets and skips the
already-present zsh snippet.

---

## 10. Extending the System

### Add a new theme

Drop a `.conf` file into `themes/` (checkout) or
`~/.config/retro-theme/themes/` (installed). No code changes needed — the engine
discovers `*.conf` automatically.

```ini
# themes/cyberpunk.conf
name=Cyberpunk
group=futuristic          # retro | futuristic | paper
fx=glow                   # crt | glow | off
background=#0a0a12
foreground=#f2f2ff
cursor=#ff2bd6
color0=#0a0a12
color1=#ff2bd6
# … define color2 … color14 …
color15=#f2f2ff
```

Requirements:
- The filename (minus `.conf`) becomes the slug, so use lowercase/hyphens.
- Provide all 19 keys: `name`, `group`, `fx`, `background`, `foreground`,
  `cursor`, and `color0`…`color15`. Colors are `#rrggbb`.
- If you ship it via the installer, add the slug to the `THEMES` list in
  `install.sh` so it gets copied during a remote install.

Verify:

```bash
retro-theme -l            # your theme should appear with its [group]
retro-theme cyberpunk     # apply it
```

### Add a new terminal adapter

Three edits in `bin/retro-theme`:

1. **Write the adapter.** Add `apply_<term>()` that reads `$TF` via
   `tget "$TF" <key>` (and `palette_of "$TF"` for the 16 colors) and writes the
   terminal's native config. Make it idempotent. Use `say`/`warn` for output and
   `command -v <dep>` guards for optional dependencies.

   ```bash
   apply_foot() {
     local cfg="$HOME/.config/foot/foot.ini" i
     # ... strip prior block, then write background/foreground/cursor + colors ...
     say "foot: colors written to $cfg"
   }
   ```

2. **Add detection.** In `detect_terminals()`, append a line that pushes the new
   id when the right env var is present:

   ```bash
   [[ -n "${FOOT_VERSION:-}" || "${TERM:-}" == foot ]] && found+=(foot)
   ```

3. **Add dispatch.** Add a case in `apply_to()` and include the id in the
   `--all` target list inside `apply_theme_cli`:

   ```bash
   # apply_to():
   foot) apply_foot;;
   # apply_theme_cli --all targets:
   targets=(ghostty windows-terminal gnome-terminal terminator kitty alacritty wezterm iterm2 foot)
   ```

If the terminal supports a screen effect, also handle its id in the `fx`
dispatch block; otherwise it falls through to the
`screen effects not supported (colors only)` warning automatically.

---

See [README.md](../README.md) for the overview and
[SETUP.md](SETUP.md) for first-time installation.
