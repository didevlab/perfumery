<div align="center">

# ghostty-retro-theme

**A CRT / retro look for the [Ghostty](https://ghostty.org) terminal — real GPU shader effects plus a theme switcher, with optional color sync to Terminator.**

[![Shell](https://img.shields.io/badge/shell-bash%20%7C%20zsh-4EAA25.svg?logo=gnu-bash&logoColor=white)](https://www.gnu.org/software/bash/)
[![Ghostty](https://img.shields.io/badge/Ghostty-1.3%2B-blueviolet.svg)](https://ghostty.org)
[![GLSL](https://img.shields.io/badge/shaders-GLSL-FF6F00.svg)](https://www.khronos.org/opengl/wiki/OpenGL_Shading_Language)

</div>

Turns Ghostty into a cool-retro-term-style CRT (screen curvature, scanlines,
phosphor glow) — but with native splits, tabs and GPU performance. Includes a
`retro-theme` command to switch palettes and screen effects on the fly, plus zsh
autocompletion.

## Features

- **CRT shader** — curvature, scanlines, vignette, phosphor glow, chromatic aberration.
- **Neon-glow shader** — a futuristic bloom effect without curvature/scanlines.
- **Theme switcher** (`retro-theme` / `rt`) — curated **retro**, **futuristic** and **paper** theme groups, plus any built-in Ghostty theme.
- **Screen-effect toggle** — `rt fx crt | glow | off`, independent of the theme.
- **zsh completion** — tab-complete themes and effects.
- **Terminator color sync** — mirrors the active theme's palette to Terminator (colors only; shaders are Ghostty-exclusive).

## Quick Start

Install everything in one line (shaders + config + `retro-theme` + zsh alias/completion):

```bash
curl -fsSL https://raw.githubusercontent.com/didevlab/perfumery/main/ghostty-retro-theme/install.sh | bash
```

Or from a checkout:

```bash
./install.sh
```

Then:

```bash
retro-theme            # interactive menu (retro / futuristic / paper)
rt "Cyberpunk"         # apply a theme directly
rt fx glow             # switch screen effect: crt | glow | off
# reload Ghostty: Ctrl+Shift+,  (or open a new window)
```

See **[docs/SETUP.md](docs/SETUP.md)** for full installation and **[docs/TECHNICAL.md](docs/TECHNICAL.md)** for how the shaders, switcher and sync work.

## Commands

| Command | Action |
|---------|--------|
| `retro-theme` / `rt` | Interactive theme menu |
| `rt "<name>"` | Apply a theme directly |
| `rt -l` | List all Ghostty themes |
| `rt fx crt` | CRT effect (curvature + scanlines) |
| `rt fx glow` | Neon-glow effect (bloom) |
| `rt fx off` | No screen effect |
| `rt fx` | Show current effect |

Theme and effect are independent — mix freely. Always reload Ghostty with
`Ctrl+Shift+,` after a change.

## Files

| File | Purpose |
|------|---------|
| `install.sh` | Idempotent installer (backs up an existing config). |
| `config` | Ghostty config template (font size, theme, shader). |
| `bin/retro-theme` | Theme + screen-effect switcher (also syncs Terminator). |
| `shaders/crt.glsl` | CRT shader: curvature, scanlines, vignette, glow. |
| `shaders/glow.glsl` | Neon-glow shader: bloom, no curvature/scanlines. |
| `zshrc-snippet.zsh` | `rt` alias + zsh completion. |

## Requirements

- [Ghostty](https://ghostty.org) 1.3+
- `zsh` (for the alias/completion; the `retro-theme` script itself is bash)
- Optional: Terminator (for color sync)

> The CRT/glow effects are Ghostty `custom-shader` (GLSL) features and cannot be
> reproduced in other terminals — Terminator only receives the color palette.

## License

[MIT](../LICENSE)
