# Setup Guide

Step-by-step guide to install **retro-theme** and apply a bundled palette to
whatever terminal you're running — from a fresh machine to a themed prompt.

`retro-theme` detects your terminal from environment variables and themes it
through that terminal's own config. The CRT/glow screen effect is applied only
where the terminal supports it (Ghostty shaders, Windows Terminal's built-in
retro effect); every other terminal gets the colors only.

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Install](#2-install)
3. [Detect Your Terminal](#3-detect-your-terminal)
4. [Apply a Theme](#4-apply-a-theme)
5. [Screen Effects (CRT / Glow)](#5-screen-effects-crt--glow)
6. [Running on WSL / Windows Terminal](#6-running-on-wsl--windows-terminal)
7. [Verify It Works](#7-verify-it-works)
8. [Troubleshooting](#8-troubleshooting)
9. [Next Steps](#9-next-steps)

---

## 1. Prerequisites

Before starting, make sure you have:

- [ ] `bash` available (the engine is a Bash 5 script)
- [ ] The terminal you want to theme — and you are **running inside it**
      (detection reads that terminal's environment variables)
- [ ] `curl` — only needed for the remote one-liner install
- [ ] `jq` — only needed if you will theme **Windows Terminal**
- [ ] `~/.local/bin` on your `PATH` (the installer warns you if it isn't)

### Verify Dependencies

```bash
bash --version
# Expected: GNU bash, version 5.x ...

command -v jq && jq --version
# Expected (only required for Windows Terminal): jq-1.6  (or similar)
```

---

## 2. Install

The installer drops the command, palettes, shaders and the `rt` alias into your
home directory. It is idempotent and backs up an existing Ghostty config.

### Option A — Remote one-liner

```bash
curl -fsSL https://raw.githubusercontent.com/didevlab/perfumery/main/retro-theme/install.sh | bash
```

### Option B — From a checkout

```bash
git clone https://github.com/didevlab/perfumery.git
cd perfumery/retro-theme
./install.sh
```

### What gets installed

| Target | Path |
|--------|------|
| `retro-theme` command | `~/.local/bin/retro-theme` |
| Bundled themes | `~/.config/retro-theme/themes/*.conf` |
| Ghostty shaders | `~/.config/ghostty/shaders/{crt,glow}.glsl` |
| Ghostty config (only if Ghostty is installed) | `~/.config/ghostty/config` |
| `rt` alias + zsh completion | appended to `~/.zshrc` |

### Verify the install

```bash
source ~/.zshrc        # load the rt alias + completion
retro-theme -l
# Expected: a list of 8 themes, e.g.
#   Retro Green        [retro]
#   Amber CRT          [retro]
#   Dracula            [futuristic]
#   ...
```

If you see `retro-theme: command not found`, add `~/.local/bin` to your `PATH`:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

---

## 3. Detect Your Terminal

`retro-theme` recognizes your terminal from the environment variables it exports.

```bash
retro-theme --detect
# Expected (example, depends on where you run it):
#   Detected: ghostty
# or:
#   Detected: windows-terminal
# or, if nothing matched:
#   Detected: none
```

Detection map (the script checks these variables):

| Terminal | Detected when |
|----------|---------------|
| Ghostty | `TERM_PROGRAM=ghostty` or `TERM=xterm-ghostty` |
| Windows Terminal | `WT_SESSION` is set |
| GNOME Terminal | `GNOME_TERMINAL_SCREEN` is set |
| Terminator | `TERMINATOR_UUID` is set |
| kitty | `KITTY_WINDOW_ID` set or `TERM=xterm-kitty` |
| Alacritty | `ALACRITTY_WINDOW_ID`/`ALACRITTY_SOCKET` set or `TERM=alacritty` |
| WezTerm | `WEZTERM_PANE` set or `TERM_PROGRAM=WezTerm` |
| iTerm2 | `TERM_PROGRAM=iTerm.app` |

> If you get `Detected: none`, you can still theme everything with `--all`
> (see step 4) — detection is just a convenience.

---

## 4. Apply a Theme

Apply to the **detected** terminal:

```bash
retro-theme "Tokyo Night"      # by display name
retro-theme tokyo-night        # …or by slug (the .conf filename)
```

Expected output (example for Ghostty):

```
==> Applying 'Tokyo Night' to: ghostty
==> Ghostty: colors written to ~/.config/ghostty/config (reload: Ctrl+Shift+,)
```

Apply to **every** supported terminal found on the machine:

```bash
retro-theme dracula --all
# Expected:
#   ==> Applying 'Dracula' to: ghostty windows-terminal gnome-terminal ...
#   (one ==> line per terminal that is present; others are skipped with [!])
```

Reload the terminal so it picks up the new colors:

| Terminal | Reload |
|----------|--------|
| Ghostty | `Ctrl+Shift+,` |
| kitty | `Ctrl+Shift+F5` |
| GNOME Terminal / Terminator | open a new window |
| Windows Terminal / Alacritty / WezTerm / iTerm2 | new window or auto-reload |

---

## 5. Screen Effects (CRT / Glow)

The screen effect is separate from the palette. It only applies where the
terminal supports it:

```bash
retro-theme fx crt     # CRT scanlines + curvature
retro-theme fx glow    # neon bloom
retro-theme fx off     # remove the effect
```

- **Ghostty** — `crt` and `glow` switch the `custom-shader` line in
  `~/.config/ghostty/config`. Reload with `Ctrl+Shift+,`.
- **Windows Terminal** — only the `crt` look exists (its built-in
  `retroTerminalEffect`). It is written when you **apply a theme** whose effect
  is `crt`; running `fx` just reminds you to re-apply.
- **All other terminals** — no shader support; you'll see
  `screen effects not supported (colors only)`.

Expected output on Ghostty:

```
==> Ghostty: effect=crt (reload: Ctrl+Shift+,)
```

Each theme also has a **default effect** (its `fx=` field): `retro-green` and
`amber` default to `crt`; `dracula`, `nord`, `tokyo-night` default to `glow`;
the rest default to `off`. Applying a theme uses that default unless you set one
explicitly with `fx`.

---

## 6. Running on WSL / Windows Terminal

This is the primary WSL use case: you run a Linux distro **inside Windows
Terminal**, and `retro-theme` patches the Windows-side `settings.json` from
inside the distro.

### 6.1 Install `jq` in the distro

```bash
sudo apt update && sudo apt install -y jq
jq --version
# Expected: jq-1.6  (or similar)
```

### 6.2 Confirm Windows Terminal is detected

Run this **in a Windows Terminal tab** (not a bare WSL console window):

```bash
retro-theme --detect
# Expected: Detected: windows-terminal
```

> `WT_SESSION` is only set inside Windows Terminal. If detection says `none`,
> you're likely in the legacy `wsl.exe` console — open a Windows Terminal tab.

### 6.3 Apply a theme

```bash
retro-theme "Amber CRT"
# Expected:
#   ==> Applying 'Amber CRT' to: windows-terminal
#   ==> Windows Terminal: scheme 'Amber CRT' applied (retro effect: true)
```

What this does under the hood:

- Locates `settings.json` under
  `/mnt/c/Users/<you>/AppData/Local/Packages/Microsoft.WindowsTerminal*/LocalState/settings.json`
  (or the unpackaged path under `.../Microsoft/Windows Terminal/settings.json`).
- Uses `jq` to add/replace a color **scheme** named after the theme, set it as
  the default profile's `colorScheme`, and toggle
  `experimental.retroTerminalEffect` on when the theme's effect is `crt`.

Because `Amber CRT` and `Retro Green` default to `crt`, they switch on the CRT
vibe automatically. To force it on/off for the current theme:

```bash
retro-theme fx crt && retro-theme "Amber CRT"   # CRT on
retro-theme fx off && retro-theme "Amber CRT"   # CRT off
```

### Verify

Open a new Windows Terminal tab — the colors and (for `crt`) the scanline effect
should be live.

---

## 7. Verify It Works

```bash
# 1. The command resolves and lists themes
retro-theme -l
# Expected: 8 themes with their [group]

# 2. Your terminal is recognized
retro-theme --detect
# Expected: Detected: <your terminal>   (not "none")

# 3. A theme applies cleanly
retro-theme nord
# Expected: ==> Applying 'Nord' to: <your terminal>  + a per-terminal ==> line
```

After reloading the terminal, the background, foreground and 16 ANSI colors
should match the chosen palette.

---

## 8. Troubleshooting

**Problem**: `retro-theme --detect` says `Detected: none`.
**Solution**: Your terminal doesn't export a recognized variable, or `tmux`/`ssh`
stripped it. Apply to all terminals instead: `retro-theme <name> --all`.

**Problem**: `retro-theme: command not found`.
**Solution**: `~/.local/bin` isn't on `PATH`. Run
`export PATH="$HOME/.local/bin:$PATH"` and add it to your shell rc, then reload.

**Problem**: Windows Terminal: `jq required` or `settings.json not found under /mnt/c`.
**Solution**: Install `jq` in the distro (`sudo apt install jq`) and make sure
Windows Terminal is installed for your Windows user so a `settings.json` exists
under `/mnt/c/Users/<you>/AppData/...`. Run from a Windows Terminal tab.

**Problem**: `themes dir not found (set RETRO_THEME_HOME)`.
**Solution**: The themes weren't installed. Re-run `install.sh`, or point the
script at a checkout: `export RETRO_THEME_HOME=/path/to/perfumery/retro-theme/themes`.

**Problem**: Colors applied but nothing changed on screen.
**Solution**: You didn't reload. Ghostty: `Ctrl+Shift+,`; kitty: `Ctrl+Shift+F5`;
GNOME Terminal / Terminator: open a new window.

**Problem**: `Terminator: no ~/.config/terminator/config, skipping`.
**Solution**: Terminator only gets patched if it already has a config. Launch
Terminator once (or create the file) so a `[[default]]` profile exists, then
re-apply.

**Problem**: `fx glow` did nothing on a non-Ghostty terminal.
**Solution**: Glow is Ghostty-only (it's a GLSL shader). Windows Terminal only
supports `crt`; other terminals support no screen effect at all.

---

## 9. Next Steps

- [ ] Add the `rt` alias to muscle memory: `rt <name>`, `rt fx crt`
- [ ] Try `retro-theme <name> --all` to theme every terminal at once
- [ ] Tweak the Ghostty look in `~/.config/ghostty/config` (font size, cursor)
- [ ] Create your own palette — see
      [TECHNICAL.md → Extending the System](TECHNICAL.md#10-extending-the-system)
- [ ] Add support for another terminal — same section covers adapters
