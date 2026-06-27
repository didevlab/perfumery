<div align="center">

# retro-theme

**Terminal-agnostic theme & screen-effect switcher — detects the terminal you're in and paints it with a bundled retro/futuristic/paper palette (plus a CRT or neon glow where the terminal supports it).**

[![Bash](https://img.shields.io/badge/bash-5.0+-4EAA25.svg?logo=gnubash&logoColor=white)](https://www.gnu.org/software/bash/)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](../LICENSE)
[![Terminals](https://img.shields.io/badge/terminals-8-blue.svg)]()
[![Themes](https://img.shields.io/badge/themes-24-orange.svg)]()

</div>

`retro-theme` is a single Bash script. It reads the standard environment
variables your terminal emulator exports (`TERM_PROGRAM`, `WT_SESSION`,
`KITTY_WINDOW_ID`, …), figures out which terminal you're sitting in, and applies
one of its bundled color palettes using that terminal's own native config
mechanism. Where the terminal can do a CRT/scanline look, it turns that on too.

There is no dependency on any specific terminal: the palettes are plain
`key=value` files bundled in this repo, so the tool works even if Ghostty (the
original target) is not installed.

---

## Features

- **Auto-detects your terminal** from environment variables — no flags needed.
- **8 terminals supported**, each themed through its own native config:
  Ghostty, Windows Terminal (WSL), GNOME Terminal, Terminator, kitty,
  Alacritty, WezTerm, iTerm2.
- **Real CRT + neon-glow shaders** on both Ghostty (GLSL) and Windows Terminal
  (HLSL `pixelShaderPath`): curvature, scanlines, vignette and bloom. Windows
  Terminal falls back to the built-in `retroTerminalEffect` if the HLSL shader
  can't be installed. Other terminals get the colors only.
- **One universal installer** — `install.sh` installs the core, then detects your
  OS/terminal and wires up the best CRT mechanism for you (Ghostty GLSL, Windows
  Terminal HLSL, a Linux compositor, or cool-retro-term), reusing the
  self-contained sub-recipes under [`effects/`](effects/). See
  [Screen Effect (CRT)](#screen-effect-crt).
- **24 bundled palettes** across 3 groups (`retro`, `futuristic`, `paper`).
- **Apply everywhere at once** with `--all` — theme every supported terminal
  found on the machine in one shot.
- **Zero terminal lock-in**: palettes are simple `.conf` files; add your own by
  dropping a file in `themes/`.
- **`rt` alias + zsh tab-completion** installed for you.

---

## Tech Stack

| Component        | Technology                                              |
|------------------|---------------------------------------------------------|
| Engine           | Bash 5 (`bin/retro-theme`)                              |
| Palettes         | Plain `key=value` `.conf` files (`themes/*.conf`)       |
| Ghostty effects  | GLSL fragment shaders (`shaders/{crt,glow}.glsl`)       |
| Windows Terminal | `jq` patching `settings.json` + HLSL `pixelShaderPath` (`shaders/{crt,glow}.hlsl`) |
| GNOME Terminal   | `gsettings` (dconf)                                     |
| Terminator       | `awk` patching `~/.config/terminator/config`            |
| Installer        | Bash + `curl` (`install.sh`)                            |

---

## Quick Start

### Prerequisites

- `bash`
- The terminal you want to theme (running inside it is how detection works)
- `jq` — only if you're theming **Windows Terminal**
- `curl` — only for the remote one-liner install

### Install

```bash
# Remote one-liner
wget -qO- https://raw.githubusercontent.com/didevlab/perfumery/main/retro-theme/install.sh | bash

# pick the CRT mechanism explicitly (default: auto-detect)
wget -qO- https://raw.githubusercontent.com/didevlab/perfumery/main/retro-theme/install.sh | bash -s -- --effect compositor

# …or from a checkout
./install.sh
./install.sh --effect cool-retro-term
```

The installer is a **universal orchestrator**: it installs the core (command,
themes, shaders, optional Ghostty config, `rt` alias), then detects your
OS/terminal and sets up the best CRT effect. Control that step with
`--effect auto|compositor|cool-retro-term|none` (default `auto`), `--no-effect`,
or the `RT_EFFECT` env var — see [Screen Effect (CRT)](#screen-effect-crt).

Then reload your shell and pick a theme:

```bash
source ~/.zshrc
retro-theme            # interactive menu (or: rt)
```

For a full walkthrough — including the WSL / Windows Terminal case — see
[docs/SETUP.md](docs/SETUP.md).

---

## Usage

```bash
retro-theme                      # interactive menu
retro-theme "Tokyo Night"        # apply by display name to the detected terminal
retro-theme tokyo-night          # …or by slug (the .conf filename)
retro-theme dracula --all        # apply to EVERY supported terminal found
retro-theme -l                   # list bundled themes
retro-theme --detect             # show which terminal was detected
retro-theme --set-default        # set Windows Terminal default profile to this WSL distro
retro-theme fx crt               # set screen effect (Ghostty / Windows Terminal)
retro-theme fx glow              # neon glow (Ghostty / Windows Terminal)
retro-theme fx off               # remove the effect
rt nord                          # the rt alias works everywhere
```

| Command | Description |
|---------|-------------|
| `retro-theme` | Interactive menu of bundled themes |
| `retro-theme <name>` | Apply a theme (display name **or** slug) to the detected terminal(s) |
| `retro-theme <name> --all` | Apply to every supported terminal on the machine |
| `retro-theme -l` | List bundled themes with their group |
| `retro-theme --detect` | Print the detected terminal(s) |
| `retro-theme --set-default [name]` | Set the Windows Terminal default profile (defaults to the current WSL distro) |
| `retro-theme fx crt\|glow\|off` | Set/clear the screen effect (Ghostty / Windows Terminal) |

---

## Bundled Themes

24 palettes across 3 groups (`retro`, `futuristic`, `paper`):

| Theme | Slug | Group | Default effect |
|-------|------|-------|:--------------:|
| Retro Green | `retro-green` | `retro` | `crt` |
| Amber CRT | `amber` | `retro` | `crt` |
| Ayu Dark | `ayu-dark` | `futuristic` | `glow` |
| Catppuccin Mocha | `catppuccin-mocha` | `futuristic` | `glow` |
| Cyberpunk Neon | `cyberpunk-neon` | `futuristic` | `glow` |
| Dracula | `dracula` | `futuristic` | `glow` |
| Everforest Dark | `everforest-dark` | `futuristic` | `off` |
| Gruvbox Dark | `gruvbox-dark` | `futuristic` | `off` |
| Gruvbox Material Dark | `gruvbox-material-dark` | `futuristic` | `off` |
| Kanagawa | `kanagawa` | `futuristic` | `glow` |
| Monokai | `monokai` | `futuristic` | `glow` |
| Night Owl | `night-owl` | `futuristic` | `glow` |
| Nord | `nord` | `futuristic` | `glow` |
| One Dark | `one-dark` | `futuristic` | `glow` |
| Rosé Pine | `rose-pine` | `futuristic` | `glow` |
| Solarized Dark | `solarized-dark` | `futuristic` | `off` |
| SynthWave '84 | `synthwave-84` | `futuristic` | `glow` |
| Tokyo Night | `tokyo-night` | `futuristic` | `glow` |
| Ayu Light | `ayu-light` | `paper` | `off` |
| Catppuccin Latte | `catppuccin-latte` | `paper` | `off` |
| GitHub Light | `github-light` | `paper` | `off` |
| Gruvbox Light | `gruvbox-light` | `paper` | `off` |
| Rosé Pine Dawn | `rose-pine-dawn` | `paper` | `off` |
| Solarized Light | `solarized-light` | `paper` | `off` |

The "default effect" is the `fx=` field in each theme file. It is used as the
effect when you apply the theme on Ghostty / Windows Terminal unless you
override it with `retro-theme fx …`.

---

## Terminal Support Matrix

| Terminal | Colors | Screen effect | How it's applied |
|----------|:------:|:-------------:|------------------|
| Ghostty | yes | CRT + glow (GLSL) | writes `~/.config/ghostty/config` + `custom-shader` |
| Windows Terminal (WSL) | yes | CRT + glow (HLSL) | `jq`-patches `settings.json`, installs an HLSL shader + sets `pixelShaderPath` (falls back to `retroTerminalEffect`) |
| GNOME Terminal | yes | — | `gsettings` on the default profile |
| Terminator | yes | — | `awk`-patches `~/.config/terminator/config` |
| kitty | yes | — | writes `~/.config/kitty/retro-theme.conf` + `include` |
| Alacritty | yes | — | writes `~/.config/alacritty/retro-theme.toml` + `import` |
| WezTerm | yes | — | writes `~/.config/wezterm/colors/<slug>.toml` |
| iTerm2 (macOS) | yes | — | writes a Dynamic Profile JSON |

> The CRT/glow **screen effect** is built into the *colors* path on Ghostty (real
> GLSL shaders) and Windows Terminal (real HLSL shaders via `pixelShaderPath`,
> with the built-in `retroTerminalEffect` as a `crt` fallback). For terminals
> without native shader support, the installer can still add a CRT via the Linux
> **compositor** or **cool-retro-term** — see [Screen Effect (CRT)](#screen-effect-crt).

### Platforms

One installer handles every OS — the CRT mechanism is chosen by detection
(Ghostty GLSL / Windows Terminal HLSL / Linux compositor / cool-retro-term).

| OS | Supported | Notes |
|----|:---------:|-------|
| **Linux** | yes | Native. Ghostty gets the GLSL CRT; without Ghostty the installer can set up a **compositor** CRT (`effects/compositor`, any terminal) or **cool-retro-term**; all terminals get the colors. |
| **Windows** | yes (via WSL) | Run it inside WSL; it themes **Windows Terminal** (`settings.json` + HLSL shader). Native PowerShell/cmd is **not** supported (the tool is a bash script). |
| **macOS** | yes | Runs on the system `bash` (3.2+) — no `mapfile`/GNU-only `sed`. Themes Ghostty, iTerm2, kitty, Alacritty, WezTerm. Without Ghostty, `--effect cool-retro-term` gives a guaranteed CRT. **Apple Terminal.app has no adapter.** |

---

## Screen Effect (CRT)

`install.sh` is a **universal orchestrator**. After installing the core it detects
your OS/terminal and sets up the best CRT mechanism, reusing the self-contained
sub-recipes under [`effects/`](effects/):

| Environment | CRT mechanism | Set up by | Turn on with |
|-------------|---------------|-----------|--------------|
| WSL | Windows Terminal HLSL shader | core (wired by `retro-theme`) | `rt fx crt` |
| Ghostty installed | GLSL shader | core | `rt fx crt` |
| Linux desktop, no Ghostty | compositor — picom (X11) / Hyprland (Wayland), CRT on **any** terminal | [`effects/compositor/install.sh`](effects/compositor/README.md) | runs during install |
| Fallback (incl. macOS without Ghostty) | cool-retro-term — dedicated CRT terminal | [`effects/cool-retro-term/install.sh`](effects/cool-retro-term/README.md) | launch `cool-retro-term` |

Choose the mechanism explicitly with `--effect auto|compositor|cool-retro-term|none`
(default `auto`), `--no-effect`, or the `RT_EFFECT` env var. In `auto` mode the
compositor path is **interactive** — the installer asks before changing your
compositor config; a non-interactive run (e.g. piped from `wget`) just prints the
command to run instead.

```
                detect OS / terminal
                         │
   ┌──────────┬──────────┼───────────────┬───────────────────┐
   v          v          v               v                   v
  WSL      Ghostty   Linux + no       (no detection)      --effect <mode>
   │          │      Ghostty             │                forces the path
   v          v          v               v
 Windows    GLSL    effects/         effects/
 Terminal  shader   compositor       cool-retro-term
  HLSL    (rt fx)   (any terminal)   (dedicated CRT)
```

The `effects/` recipes are self-contained (each has its own README + `docs/`):

- [`effects/compositor/`](effects/compositor/README.md) — CRT via the Linux compositor, terminal-independent (X11/picom per-window, Hyprland/Wayland whole-screen).
- [`effects/cool-retro-term/`](effects/cool-retro-term/README.md) — a dedicated CRT terminal emulator (Linux/macOS); the CRT look is guaranteed regardless of shell or terminal.

---

## Architecture

```
                 ┌────────────────────────────────────────┐
                 │            retro-theme (Bash)           │
                 └────────────────────────────────────────┘
                                    │
            ┌───────────────────────┼────────────────────────┐
            v                       v                         v
   ┌──────────────────┐  ┌────────────────────┐  ┌────────────────────┐
   │ detect_terminals │  │  theme_file /      │  │  set_fx_ghostty    │
   │ (env vars →      │  │  tget / palette_of │  │  (CRT/glow shader) │
   │  terminal ids)   │  │  (read .conf)      │  └────────────────────┘
   └──────────────────┘  └────────────────────┘
            │                       │
            └───────────┬───────────┘
                        v
              ┌──────────────────┐
              │   apply_to()     │  dispatch by terminal id
              └──────────────────┘
                        │
   ┌────────┬───────────┼───────────┬─────────┬──────────┬─────────┐
   v        v           v           v         v          v         v
apply_   apply_      apply_      apply_     apply_     apply_    apply_
ghostty  windows_t.  gnome_t.    terminator kitty      alacritty wezterm  …iterm2
```

See [docs/TECHNICAL.md](docs/TECHNICAL.md) for the full breakdown.

---

## Folder Structure

```
retro-theme/
├── bin/
│   └── retro-theme          # the engine + one adapter per terminal
├── themes/                  # 24 bundled palettes (key=value .conf files)
│   ├── retro-green.conf     # group: retro
│   ├── amber.conf           # group: retro
│   ├── ayu-dark.conf        # group: futuristic
│   ├── catppuccin-mocha.conf
│   ├── cyberpunk-neon.conf
│   ├── dracula.conf
│   ├── everforest-dark.conf
│   ├── gruvbox-dark.conf
│   ├── gruvbox-material-dark.conf
│   ├── kanagawa.conf
│   ├── monokai.conf
│   ├── night-owl.conf
│   ├── nord.conf
│   ├── one-dark.conf
│   ├── rose-pine.conf
│   ├── solarized-dark.conf
│   ├── synthwave-84.conf
│   ├── tokyo-night.conf
│   ├── ayu-light.conf       # group: paper
│   ├── catppuccin-latte.conf
│   ├── github-light.conf
│   ├── gruvbox-light.conf
│   ├── rose-pine-dawn.conf
│   └── solarized-light.conf
├── shaders/                 # screen effects: GLSL (Ghostty) + HLSL (Windows Terminal)
│   ├── crt.glsl             # Ghostty: curvature + scanlines + vignette
│   ├── glow.glsl            # Ghostty: neon bloom
│   ├── crt.hlsl             # Windows Terminal: curvature + scanlines + vignette
│   └── glow.hlsl            # Windows Terminal: neon bloom
├── config                   # optional sample Ghostty config
├── zshrc-snippet.zsh        # rt alias + zsh completion
├── install.sh               # universal installer / orchestrator (local or curl|bash)
├── effects/                 # CRT effect sub-recipes wired up by the orchestrator
│   ├── compositor/          # CRT via the Linux compositor (picom X11 / Hyprland Wayland)
│   │   ├── install.sh       #   self-contained installer
│   │   ├── shaders/         #   picom-crt.glsl + hyprland-crt.frag
│   │   ├── README.md
│   │   └── docs/            #   SETUP.md + TECHNICAL.md
│   └── cool-retro-term/     # dedicated CRT terminal emulator (Linux/macOS)
│       ├── install.sh       #   self-contained installer
│       ├── tmux.conf        #   bundled ~/.tmux.conf (tabs/splits)
│       ├── README.md
│       └── docs/            #   SETUP.md + TECHNICAL.md
├── README.md
└── docs/
    ├── SETUP.md             # zero-to-running walkthrough
    └── TECHNICAL.md         # architecture & extension points
```

---

## Troubleshooting

**Problem**: `retro-theme --detect` prints `Detected: none`.
**Solution**: Your terminal doesn't export a recognized env var (or you're in
`tmux`/`ssh`, which can strip them). Use `retro-theme <name> --all` to theme every
supported terminal regardless of detection.

**Problem**: Windows Terminal isn't themed.
**Solution**: Install `jq` inside your WSL distro (`sudo apt install jq`) and make
sure the Windows-side `settings.json` exists under `/mnt/c/Users/<you>/...`.

**Problem**: `retro-theme: command not found`.
**Solution**: `~/.local/bin` isn't on your `PATH`. Add
`export PATH="$HOME/.local/bin:$PATH"` to your shell rc and reload.

See [docs/SETUP.md](docs/SETUP.md#5-troubleshooting) for more.

---

## License

[MIT](../LICENSE)
