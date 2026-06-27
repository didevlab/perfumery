# Setup Guide

Step-by-step guide to install the retro CRT theme and shaders for Ghostty,
switch themes/effects with the `retro-theme` command, and optionally mirror the
palette to Terminator.

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Install with install.sh](#2-install-with-installsh)
3. [Manual Install](#3-manual-install)
4. [Reload and Verify](#4-reload-and-verify)
5. [Switch Themes and Effects](#5-switch-themes-and-effects)
6. [Terminator Color Sync](#6-terminator-color-sync)
7. [Troubleshooting](#7-troubleshooting)
8. [Next Steps](#8-next-steps)

---

## 1. Prerequisites

Before starting, make sure you have:

- [ ] [Ghostty](https://ghostty.org) **1.3+** installed
- [ ] `zsh` as your shell (the `rt` alias + tab completion are zsh; the `retro-theme` script itself is bash)
- [ ] `~/.local/bin` on your `PATH`
- [ ] Optional: Terminator installed (only if you want color sync)

### Verify Dependencies

```bash
ghostty --version
# Expected: Ghostty 1.3.x (or newer)

echo "$SHELL"
# Expected: /usr/bin/zsh  (or /bin/zsh)

ghostty +list-themes | head -3
# Expected: a list of built-in themes (confirms Ghostty's theme support works)
```

> **If `ghostty` is not found**, install it first (e.g. `sudo snap install ghostty`).
> The installer warns but continues if Ghostty is missing.

---

## 2. Install with install.sh

The installer is idempotent and backs up any existing Ghostty config.

```bash
chmod +x install.sh
./install.sh
# Expected (truncated):
# ==> Installing shaders into ~/.config/ghostty/shaders/
# ==> Installing config into ~/.config/ghostty/config
# ==> Installing the retro-theme command into ~/.local/bin/
# ==> Adding alias + autocomplete to ~/.zshrc
# ==> Done!
```

What it does:

| Step | Destination |
|------|-------------|
| Copies `crt.glsl`, `glow.glsl` | `~/.config/ghostty/shaders/` |
| Backs up an existing config | `~/.config/ghostty/config.bak.<timestamp>` |
| Installs the config template | `~/.config/ghostty/config` |
| Installs the switcher | `~/.local/bin/retro-theme` |
| Appends alias + completion | `~/.zshrc` |

> **Warning**: the installer overwrites `~/.config/ghostty/config` with the
> template (after backing the old one up as `config.bak.*`). If you have a
> customized config, merge your settings back in from the backup afterward.

---

## 3. Manual Install

If you prefer not to run the installer, do the equivalent by hand:

```bash
# 1. Shaders
mkdir -p ~/.config/ghostty/shaders
cp shaders/crt.glsl  ~/.config/ghostty/shaders/
cp shaders/glow.glsl ~/.config/ghostty/shaders/

# 2. Config (back up your own first if it exists)
cp ~/.config/ghostty/config ~/.config/ghostty/config.bak 2>/dev/null || true
cp config ~/.config/ghostty/config

# 3. The switcher command
mkdir -p ~/.local/bin
cp bin/retro-theme ~/.local/bin/retro-theme
chmod +x ~/.local/bin/retro-theme

# 4. Alias + zsh completion
cat zshrc-snippet.zsh >> ~/.zshrc
```

If `~/.local/bin` is not on your `PATH`, add this to `~/.zshrc`:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

---

## 4. Reload and Verify

```bash
# Reload the shell so the alias, completion, and PATH take effect
source ~/.zshrc

# Confirm the command is found
command -v retro-theme
# Expected: ~/.local/bin/retro-theme

# Confirm the shaders landed
ls ~/.config/ghostty/shaders/
# Expected: crt.glsl  glow.glsl

# Confirm the config points at a shader and theme
grep -E '^(theme|custom-shader) =' ~/.config/ghostty/config
# Expected:
# theme = Retro
# custom-shader = shaders/crt.glsl
```

Now **reload Ghostty** so it picks up the new config:

- Press **Ctrl+Shift+,** inside Ghostty (reload config), **or** open a new window.

You should see the CRT effect: gentle screen curvature, scanlines, a soft
phosphor glow, and the green `Retro` palette. Tab completion works too:

```bash
rt <TAB>
# Expected: completes with 'fx', '-l', and the list of Ghostty theme names
```

---

## 5. Switch Themes and Effects

```bash
retro-theme            # interactive menu, grouped: RETRO / FUTURISTIC / PAPER
# Expected:
# == RETRO ==
#    1) Retro
#    2) Hipster Green
#    ...
# Choose [1-21]:

rt "Cyberpunk"         # apply a theme directly
# Expected:
# Theme: Cyberpunk
# Reload Ghostty: Ctrl+Shift+,  ...

rt fx glow             # switch the screen effect (crt | glow | off)
# Expected:
# Effect: futuristic glow
# Reload Ghostty: Ctrl+Shift+,  ...

rt fx                  # show the current effect
# Expected: Current effect: glow

rt -l                  # list ALL Ghostty themes
```

Theme and effect are independent — pick any combination. **Always reload Ghostty
(Ctrl+Shift+,) after a change** for it to take effect.

---

## 6. Terminator Color Sync

If Terminator is installed, `retro-theme` mirrors the **active theme's palette**
into `~/.config/terminator/config` automatically whenever you apply a theme
(the CRT/glow shaders are Ghostty-only and cannot be reproduced in Terminator).

```bash
rt "Synthwave"
# Expected (when Terminator is present):
# Theme: Synthwave
# Terminator synced.
```

Open a **new** Terminator window to see the new colors (existing windows keep the
old palette).

For sync to work, Terminator must already have a `[[default]]` profile block in
`~/.config/terminator/config`. If the file or block doesn't exist, the sync is
silently skipped (Ghostty is still themed normally).

---

## 7. Troubleshooting

**Problem**: `ghostty: command not found` during install (the `[!]` warning).
**Solution**: Ghostty isn't on your `PATH`. Install it (e.g. `sudo snap install ghostty`) and re-run `./install.sh`. The installer is idempotent, so re-running is safe.

**Problem**: The theme applies but the CRT/glow effect doesn't show.
**Solution**: The shader path is relative to the config dir. Confirm `custom-shader = shaders/crt.glsl` in `~/.config/ghostty/config` **and** that the files exist at `~/.config/ghostty/shaders/crt.glsl` / `glow.glsl`. Then reload with Ctrl+Shift+,. Also check your GPU/driver supports `custom-shader` — run `ghostty` from another terminal and look for shader-compile errors in its output.

**Problem**: `rt <TAB>` doesn't complete themes, or `rt` isn't a known command.
**Solution**: Run `source ~/.zshrc`. If completion still doesn't work, confirm the `# === retro-theme: alias + autocomplete ===` block is present in `~/.zshrc` and that you're in zsh (`echo $0`). The snippet runs `compinit`; if another tool manages `compinit`, ordering can matter — make sure the snippet is sourced after your completion framework initializes.

**Problem**: Terminator colors don't change after applying a theme.
**Solution**: Sync only runs if both the Ghostty theme file (`/snap/ghostty/current/share/ghostty/themes/<name>`) and `~/.config/terminator/config` exist, and the config has a `[[default]]` profile. Open a **new** Terminator window after syncing (running windows aren't updated). If you installed Ghostty somewhere other than via snap, edit `THEMES_DIR` near the top of `~/.local/bin/retro-theme` to point at your themes directory.

**Problem**: `retro-theme: command not found` even after sourcing `~/.zshrc`.
**Solution**: `~/.local/bin` isn't on your `PATH`. Add `export PATH="$HOME/.local/bin:$PATH"` to `~/.zshrc` and `source ~/.zshrc`. Verify with `command -v retro-theme`.

**Problem**: The CRT effect looks too strong (too much curvature, scanlines too dark, glow too bright).
**Solution**: Tune the constants in `~/.config/ghostty/shaders/crt.glsl` and reload. Common knobs: scanline depth (`* 0.08` in the `scan` line — lower it), phosphor mask strength (`0.92 + 0.08 *` — raise the base toward 1.0), overall brightness (`col *= 1.12`), and curvature (the `/ 4.0` and `/ 3.5` divisors in `curve()` — larger = flatter). For `glow.glsl`, reduce the bloom amount (`* 0.45`).

---

## 8. Next Steps

- [ ] Confirm `command -v retro-theme` resolves to `~/.local/bin/retro-theme`
- [ ] Reload Ghostty (Ctrl+Shift+,) and confirm the CRT effect renders
- [ ] Try each effect: `rt fx crt`, `rt fx glow`, `rt fx off`
- [ ] Explore theme groups via the interactive `retro-theme` menu
- [ ] If you use Terminator, apply a theme and open a new window to confirm sync
- [ ] Read [TECHNICAL.md](TECHNICAL.md) to understand the shaders, switcher, and sync
- [ ] Optionally tune shader constants to taste (see troubleshooting above)
