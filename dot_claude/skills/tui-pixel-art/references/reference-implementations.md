# Reference Implementations (Annotated)

Real half-block / character art in the wild, and what to learn from each. Study
these when building something substantial.

## pixtuoid — Ratatui sprite engine
`github.com/IvanWng97/pixtuoid`

A pixel-art sprite engine rendered in a real Ratatui TUI. Pipeline: **pose →
pixel_painter → RgbBuffer → half-block → ratatui**, running ~30 fps. The closest
analog to this skill's approach: an in-memory RGB buffer converted to half-block
cells and written into Ratatui's `Buffer`, with sprite packs and animation.
**Lesson:** the canonical architecture — keep an RGB buffer, convert to
half-blocks at render time, let Ratatui diff. Mirror this for anything beyond a
static asset. See `ratatui.md`.

## rebels-in-the-sky — custom half-block renderer at scale
`github.com/ricott1/rebels-in-the-sky`

A full P2P terminal game (space pirates, basketball sim) over SSH. Decodes
GIF/PNG sprite assets to RGBA and writes per-cell fg/bg half-block cells into the
buffer — a **custom half-block renderer**, deps `gif` + `image` + `ratatui`,
**notably not `ratatui-image`**. Recommends a 160×48 terminal. **Lesson:** at
real scale, teams still hand-roll the half-block renderer for control over
transparency, palette, and animation rather than using a generic image widget.
Confirms the grid→Buffer pattern is the production choice. (Same author:
`sshattrick`, another half-block Ratatui game.)

## notcurses — the blitter ladder
`github.com/dankamongmen/notcurses`

The reference for graceful degradation. Its blitters form a quality ladder —
**octant (2×4) → sextant (2×3) → quadrant (2×2) → half (1×2) → ASCII** — each
selected by terminal/font capability. The author's notes are the best practical
writeup of where each density technique shines and where color loss does/doesn't
hurt. **Lesson:** always have a fallback chain; detect capability and degrade.
See `density-techniques.md`.

## GitHub Copilot CLI banner — production animation architecture
(built with the ASCII Motion tool; shipped in `@github/copilot`)

An animated startup banner that's the gold standard for *shippable* terminal
animation. Key architecture decisions:
- **Plain-text frames** + **semantic color roles** per cell (`{"row,col": role}`)
  — geometry and color are separate, so themes recolor without touching frames.
- **Runtime theming** with light/dark variants.
- **4-bit (16-color)** output for maximum portability and themeability.
- **DECSET 2026** synchronized output for flicker-free repaint.
- **~13 fps (75 ms/frame)**; the team warns higher rates cause flicker.
- **~3-second** intro, **opt-in**, **skipped under `--screen-reader`**,
  non-blocking.
**Lesson:** this is the template for any shipped CLI animation. Separate color
from geometry, target 16-color with roles, use 2026, keep it short and
accessible. See `animation.md` and the "separate geometry from color" section of
`SKILL.md`.

## Claude Code mascot — brand color in art
The orange creature uses `rgb(215,119,87)`. **Lesson:** a single, consistent
brand color anchors a mascot; pick it deliberately and carry it across all art.
(Note: 16-color can't represent this orange — ship it in 256/truecolor, or map it
to a themeable role.)

## plastic — the contrasting choice (and why half-blocks exist)
`github.com/Amjad50/plastic`

A NES emulator with a TUI frontend that renders **one full character per pixel**
(via `tui`/Ratatui + `image`), not half-blocks. Because a cell is ~2× taller than
wide, full-char-per-pixel makes the picture **2× vertically stretched** and chunky
— acceptable for a retro emulator aesthetic, wrong for proportional art.
**Lesson:** this is the negative example that proves why half-blocks are the
default — they restore square pixels. Use full-char-per-pixel only when you
*want* chunky 2:1 pixels.

## Tools worth knowing (not implementations to copy)
- **Ascii-Motion** (`cameronfoxly/Ascii-Motion`) / ascii-motion.app — the editor
  behind the Copilot banner; see `ascii-motion-mcp.md`.
- **unicode-art** (`Botspot/unicode-art`) — image→Unicode conversion reference.
- **pixterm**, **chafa**, **ratatui-image**, **viuer** — image→symbol renderers;
  chafa is the most complete (`chafa.md`).
