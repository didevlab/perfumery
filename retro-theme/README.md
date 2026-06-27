<div align="center">

# retro-theme

**Terminal-agnostic theme & screen-effect switcher — detects the terminal you're in and paints it with a bundled retro/futuristic/paper palette (plus a CRT or neon glow where the terminal supports it).**

[![Bash](https://img.shields.io/badge/bash-5.0+-4EAA25.svg?logo=gnubash&logoColor=white)](https://www.gnu.org/software/bash/)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](../LICENSE)
[![Terminals](https://img.shields.io/badge/terminals-8-blue.svg)]()
[![Themes](https://img.shields.io/badge/themes-8-orange.svg)]()

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
- **Screen effects where possible**: real CRT/scanline + neon glow via GLSL
  shaders on Ghostty; the built-in `retroTerminalEffect` on Windows Terminal.
  Other terminals get the colors only.
- **8 bundled palettes** across 3 groups (`retro`, `futuristic`, `paper`).
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
| Windows Terminal | `jq` patching `settings.json`                           |
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
curl -fsSL https://raw.githubusercontent.com/didevlab/perfumery/main/retro-theme/install.sh | bash

# …or from a checkout
./install.sh
```

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
retro-theme fx crt               # set screen effect (Ghostty / Windows Terminal)
retro-theme fx glow              # neon glow (Ghostty only)
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
| `retro-theme fx crt\|glow\|off` | Set/clear the screen effect |

---

## Bundled Themes

| Theme | Slug | Group | Default effect |
|-------|------|-------|:--------------:|
| Retro Green | `retro-green` | `retro` | `crt` |
| Amber CRT | `amber` | `retro` | `crt` |
| Dracula | `dracula` | `futuristic` | `glow` |
| Nord | `nord` | `futuristic` | `glow` |
| Tokyo Night | `tokyo-night` | `futuristic` | `glow` |
| Gruvbox Dark | `gruvbox-dark` | `futuristic` | `off` |
| Gruvbox Light | `gruvbox-light` | `paper` | `off` |
| Solarized Light | `solarized-light` | `paper` | `off` |

The "default effect" is the `fx=` field in each theme file. It is used as the
effect when you apply the theme on Ghostty / Windows Terminal unless you
override it with `retro-theme fx …`.

---

## Terminal Support Matrix

| Terminal | Colors | Screen effect | How it's applied |
|----------|:------:|:-------------:|------------------|
| Ghostty | yes | CRT + glow (GLSL) | writes `~/.config/ghostty/config` + `custom-shader` |
| Windows Terminal (WSL) | yes | CRT (`retroTerminalEffect`) | `jq`-patches the Windows-side `settings.json` |
| GNOME Terminal | yes | — | `gsettings` on the default profile |
| Terminator | yes | — | `awk`-patches `~/.config/terminator/config` |
| kitty | yes | — | writes `~/.config/kitty/retro-theme.conf` + `include` |
| Alacritty | yes | — | writes `~/.config/alacritty/retro-theme.toml` + `import` |
| WezTerm | yes | — | writes `~/.config/wezterm/colors/<slug>.toml` |
| iTerm2 (macOS) | yes | — | writes a Dynamic Profile JSON |

> The CRT/glow **screen effect** only exists on Ghostty (real GLSL shaders) and
> Windows Terminal (its built-in retro effect). Every other terminal gets the
> colors only.

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
├── themes/                  # bundled palettes (key=value .conf files)
│   ├── retro-green.conf
│   ├── amber.conf
│   ├── dracula.conf
│   ├── nord.conf
│   ├── tokyo-night.conf
│   ├── gruvbox-dark.conf
│   ├── gruvbox-light.conf
│   └── solarized-light.conf
├── shaders/                 # Ghostty-only GLSL screen effects
│   ├── crt.glsl             # curvature + scanlines + vignette
│   └── glow.glsl            # neon bloom
├── config                   # optional sample Ghostty config
├── zshrc-snippet.zsh        # rt alias + zsh completion
├── install.sh               # installer (local or curl|bash)
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
