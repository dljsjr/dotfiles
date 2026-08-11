---
name: tui-pixel-art
description: "Create small, raster-style art for terminal/TUI apps using Unicode half-block characters (▀ ▄) with ANSI color: mascots, logos, icons, splash headers, game sprites, and animations. Use whenever the user wants terminal, TUI, or CLI art, ASCII/Unicode pixel art, a terminal logo, banner, or splash screen, a mascot or sprite for a terminal game or coding agent, a half-block image renderer, an animated header or loader, or to convert a simple image or re-interpret detailed reference art into a small embeddable terminal asset or Ratatui pixel widget. Covers the half-block technique, higher-density quadrant/sextant/octant/Braille blitting, color quantization, dithering, runtime-agnostic and Ratatui rendering, and flicker-free animation. For deliberate, SMALL, embeddable assets that communicate an idea, not max-resolution image dumping, using only real Unicode characters. Never Sixel, Kitty graphics, iTerm2 inline images, or other image protocols; if the user wants those, this skill does not apply."
---

# TUI Pixel Art (Unicode Half-Blocks)

Draw raster-style graphics in a terminal using **real Unicode characters plus
ANSI color** — no image protocols. The output is plain colored text that renders
in any modern terminal, embeds directly in source, and works inside TUI
frameworks (Ratatui and friends) or with no framework at all.

## What this skill is for (and what it is not)

The goal is **deliberate, small, embeddable art that communicates an idea**: a
mascot, a logo, a splash header, a game sprite, a status-line pet, a short
animation. Think the orange creature in a coding-agent CLI, an animated startup
banner, a sprite in a terminal game. These assets are small (often 8–80 cells
wide) but carry enough fidelity to read clearly.

This is **not** about taking an arbitrary photo and rendering it at maximum
resolution. If someone wants photographic fidelity, that calls for an image
protocol (Sixel / Kitty graphics / iTerm2 inline) — which is **explicitly out of
scope**. This skill is *only* Unicode-character art. Reach for it when the value
is a crisp, intentional, small asset that lives happily in a text grid.

## The core technique: vertical half-block

A terminal cell shows **one glyph with one foreground color and one background
color**. Print the upper-half-block character and the foreground paints the top
half of the cell while the background paints the bottom half — **two
independently colored pixels stacked in one cell**:

```
U+2580  ▀  UPPER HALF BLOCK   fg → top pixel, bg → bottom pixel
U+2584  ▄  LOWER HALF BLOCK   fg → bottom pixel, bg → top pixel
U+2588  █  FULL BLOCK         (rarely needed; a space + bg color is cheaper)
space      (default bg)       transparent / empty cell
```

To draw a bitmap, walk the pixel grid **two rows at a time**: source row `2N`
becomes the top color, row `2N+1` the bottom color, emitted as one `▀` cell.

The exact escape sequence for one truecolor cell (green over red):

```
ESC[38;2;0;255;0m   ESC[48;2;255;0;0m   ▀   ESC[0m
\___fg = top pixel_/ \__bg = bottom px_/ glyph  reset
```

**Why this works and why it matters:** terminal cells are ~2× taller than wide,
so splitting a cell into top/bottom halves yields **roughly square pixels** and
the art keeps its proportions. (Rendering one *full* character per pixel instead
stretches everything 2× vertically — that distortion is the whole reason the
half-block technique exists. The only time full-character-per-pixel is right is
when you deliberately want chunky 2:1 pixels.)

For a half-transparent cell, keep the terminal background on the empty side: use
`▀` with only a foreground (top pixel set, bottom transparent), or `▄` with only
a foreground (bottom set, top transparent). A fully empty cell is a space.

## The most important architectural decision: separate geometry from color

The single biggest lesson from real production TUI art (GitHub built the Copilot
CLI's animated banner this way): **do not bake colors into your art.** Store the
*shape* as a grid, store *which role* each pixel plays, and resolve roles to
actual colors at render time. This is what makes art themeable, accessible, and
adaptable across terminals.

Concretely, the canonical artifact is a **color grid** plus a renderer:

- **Geometry**: a 2D grid where each pixel is transparent or carries a color (or
  a *semantic role* like `body`, `outline`, `eye`, `shadow`).
- **Palette / theme**: a mapping from role → color, ideally with light/dark
  variants. For shippable CLI art, prefer a small palette that can be re-themed.
- **Renderer**: turns the grid into half-block cells at the chosen color depth.

Baking raw ANSI escapes into a string is fine for a one-off, but it freezes the
color, can't downgrade across terminals, and breaks if a host trims trailing
blanks. **Default to a grid + renderer.** The bundled scripts implement exactly
this pattern, so you rarely write a renderer by hand.

## Use the bundled scripts — don't reinvent the renderer

Three scripts in `scripts/` do the mechanical work. They are **pure standard
library** (except the image importer, which needs Pillow), so generated assets
and the renderer embed anywhere. When you hand the user a drop-in helper, copy
(*vendor*) `halfblock_render.py` next to the asset and import it relatively —
don't `sys.path.insert` the skill's own install directory, which won't exist on
the user's machine.

### `scripts/halfblock_render.py` — grid → half-block text (the core)

Renders a grid to ANSI half-block output. Library and CLI.

```bash
python3 scripts/halfblock_render.py asset.json                 # truecolor
python3 scripts/halfblock_render.py asset.json --color 256     # 256-color downgrade
python3 scripts/halfblock_render.py asset.json --color 16      # 16-color downgrade
python3 scripts/halfblock_render.py asset.json --ascii         # no-color SHAPE check
```

The `--ascii` mode prints a brightness silhouette (one char per pixel, no
color). Use it to verify an asset's **shape** in a plain log when you can't see
terminal color — invaluable for checking your work.

As a library:

```python
from halfblock_render import load_grid, render
print(render(load_grid("asset.json"), color="truecolor"))
```

### `scripts/preview.py` — play a still or an animation (flicker-free)

```bash
python3 scripts/preview.py asset.json            # show a still
python3 scripts/preview.py walk.anim.json        # loop an animation (Ctrl-C)
python3 scripts/preview.py walk.anim.json --once  # play once
python3 scripts/preview.py walk.anim.json --ascii # silhouette every frame (shape check)
```

Wraps every repaint in **synchronized output (DECSET 2026)** so frames swap
atomically with no flicker, repaints in place (cursor-up, not full clear), hides
the cursor, and falls back to stacked output when piped. See
`references/animation.md` for the why and the data model.

### `scripts/image_to_grid.py` — PNG/JPG → grid (needs Pillow)

The **conversion** path — mechanically downscale + quantize an existing image
into a grid, no chafa required. Right when the source is already simple/iconic or
the target is large enough to carry its detail. When the source is detailed and
the target is small, *don't convert* — re-interpret it (redraw by hand); see
"Bringing in reference art" below.

```bash
python3 scripts/image_to_grid.py logo.png --width 40 -o logo.json
python3 scripts/image_to_grid.py logo.png --width 24 --colors 16 --dither floyd -o logo.json
python3 scripts/image_to_grid.py logo.png --width 32 | python3 scripts/halfblock_render.py /dev/stdin
```

`--width` is in **pixels**; height is derived from aspect (half-blocks are
square). With half-blocks the output **cell-width equals the pixel-width (1:1)
and cell-height is pixel-height ÷ 2**, so to stay under *N* cells wide pass
`--width N` (or less) — the renderer echoes the mapping as a `[W×H px → cells]`
header, so glance at it to confirm. Keep widths small (24–64); cranking the
width to "fit the image" defeats the purpose and produces huge escape blobs.

**Match the filter to the source.** Flat, hard-edged art (logos, icons, pixel
sprites) wants `--nearest` and **no** dithering — that keeps edges crisp and the
exact brand colors intact (skip `--colors`, since quantization silently shifts
flat hues to muddy tones). Photographic / gradient sources want the default
smooth resample plus `--dither floyd`. Reaching for the default Lanczos +
median-cut on a logo blurs its edges and is the usual cause of off-brand color.

## The asset formats

Two JSON formats, both consumed by every script. The authoritative schema (pixel
data model, sprite-vs-rgb selection, `null`/transparency semantics) is documented
in the `scripts/halfblock_render.py` module docstring; the short version:

**Sprite format** (hand-authorable — recommended for drawn assets). Each char in
`rows` indexes `palette`; `null` is transparent. Reads like pixel art in source
and diffs cleanly:

```json
{
  "palette": {".": null, "O": [222,128,92], "k": [38,28,24]},
  "rows": ["..OO..", ".OkkO.", "OOOOOO"]
}
```

**RGB format** (the image importer's default output; it can also emit the sprite
format above via `--format sprite`):

```json
{"width": 6, "height": 3, "pixels": [[[222,128,92], null, ...], ...]}
```

See `assets/examples/mascot.json` for a complete worked sprite and
`assets/examples/dot.anim.json` for an animation.

## Bringing in reference art: convert vs. re-interpret

Two different operations — and using the wrong one is the usual cause of garbage
output:

- **Convert** — downscale + quantize + dither the source (`image_to_grid.py`,
  chafa). Faithful, mechanical. Right when the source is already simple/iconic, or
  the target is large enough (≈≥ 32×32 px) to carry the detail.
- **Re-interpret** — *you redraw* the subject at the target size, choosing what to
  keep, what to drop, and how to suggest detail with a few pixels. Right when the
  source is detailed/busy and the target is small (a few cell-rows), or when you
  want a stylized asset that captures an essence rather than a copy.

Downsampling can only average; it cannot abstract. At a small cell budget,
averaging a rich image smears away the very features that make it recognizable —
the result is an unintelligible blob, and dithering makes it worse. The fix is not
a better filter: **redraw it.** Re-interpretation is an authoring act you perform
with your own visual understanding — block the silhouette, keep the 2–4
identifying features, pick a deliberate (often punchier-than-source) palette, and
use `halfblock_render.py --ascii` and `preview.py` to *check* the redraw, not to
produce it. There is no tool for this part; that's the point. Full method in
**`references/reinterpretation.md`** — read it whenever you're handed inspiration
art and a tight size budget.

## Authoring workflow

1. **Design small, at pixel resolution.** Decide the cell footprint first (see
   sizes below), remembering each cell-row is two pixel-rows. When the user
   stresses *small / tiny / nothing huge*, aim for the lower half of the size
   band and only grow if a feature won't read in `--ascii`. Sketch in the sprite
   format, in a pixel editor, or with the ASCII Motion tool
   (`references/ascii-motion-mcp.md`).
2. **Choose a constrained, semantic palette.** 4–8 colors is plenty for small
   art. Name roles (`body`, `outline`, `eye`, `shadow`) rather than hard-coding
   hues, so the asset can be re-themed and made accessible. Prefer a palette that
   survives a 16-color downgrade if the asset ships in a CLI others will theme.
3. **Map to half-blocks** via `halfblock_render.py` (or quadrants/sextants for
   more density — `references/density-techniques.md`).
4. **Preview and shape-check** with `preview.py` and `--ascii`.
5. **Embed.** Ship the grid + renderer, or export to your framework. For
   Ratatui, see `references/ratatui.md`. For the runtime-agnostic path, the
   rendered ANSI string prints anywhere.

**Recommended sizes** (cells wide × cells tall → effective pixels):

| Asset | Cells (w×h) | ~Pixels |
|---|---|---|
| Status-line pet / icon | 5–8 × 2–4 | up to 8×8 |
| Small mascot / sprite | 8–16 × 6–12 | up to 16×24 |
| Logo / splash header | 40–80 × 8–14 | the Copilot banner was 78×11 cells |
| Full-screen sprite scene | up to ~160 × 48 | (game territory) |

Stay under 80 columns for headers unless you control the terminal — 80 is the
safe floor.

## Picking a technique: half-block is the default

Half-blocks are the right default for **colored** art: universal font support,
two full colors per cell, square pixels. Reach past them only for a reason:

| Need | Technique | Trade-off | Reference |
|---|---|---|---|
| Colored art (default) | **half-block ▀▄** (1×2) | 2 colors/cell, square px | this file |
| More horizontal detail | quadrants (2×2) | still 2 colors/cell | `density-techniques.md` |
| Higher-res colored art | sextants (2×3), octants (2×4) | needs newer fonts | `density-techniques.md` |
| Monochrome line art / plots | Braille (2×4 dots) | one color per cell | `density-techniques.md` |
| Gradients / shading / depth | shade chars ░▒▓ | texture, not resolution | `color-and-dithering.md` |

The hard constraint across **all** of these: **two colors per cell, maximum.**
More sub-pixel resolution never buys more colors. That's why half-blocks win for
colored art — they spend their two colors on the fewest, largest sub-pixels.

## Color depth and dithering (summary)

- **Truecolor** (`38;2;r;g;b`): brand-accurate, but unsupported on some
  terminals and *ignores* user themes.
- **256-color** (`38;5;n`): good middle ground; handles browns/oranges that
  16-color can't.
- **16-color** (`30–37/90–97`): the only depth users can re-theme, so it's the
  accessible/portable choice — but it has no brown/orange and approximates
  everything else. Design within its gamut if you target it.

For palette reduction and dithering (Floyd–Steinberg vs ordered/Bayer), choosing
the best two colors per cell, and transparency handling, see
`references/color-and-dithering.md`.

## Legibility for tiny art

Small art lives or dies on these:

- **Silhouette first.** A clear outline reads better than internal detail at
  small sizes. Check it with `--ascii`.
- **Limit the palette and crank contrast.** 4–8 colors; avoid adjacent near-hues
  that muddy together.
- **Outline the subject.** A dark 1-px outline (or a transparent-background edge)
  separates the sprite from whatever's behind it.
- **Design square; let half-blocks keep it square.** Don't pre-stretch.
- **Test across terminals and themes.** Colors get remapped by themes; what looks
  right in your terminal may not elsewhere. This is why semantic roles + a small
  palette matter.
- **Mind trailing-blank trimming and wide glyphs.** Some hosts strip trailing
  spaces (which can eat transparent cells); emoji/CJK glyphs are double-width and
  break alignment — keep them out of art rows. Use a matte (see the renderer's
  `--matte`) when a host trims blanks.

## Animation (summary)

Frame-based: store frames, repaint on a timer. The essentials — cursor
repositioning, ~10–15 fps timing, and **synchronized output (DECSET 2026)** to
kill flicker — are implemented in `preview.py`. The animation data model, sprite
sheets, flicker avoidance, and players are in **`references/animation.md`**. Read
it whenever the task involves motion (banners, walk cycles, loaders, thinking
animations).

## Authoring tools and pipelines

- **ASCII Motion** (`references/ascii-motion-mcp.md`) — a web editor for ASCII /
  half-block art and animation **with an MCP server** (70+ tools) you can drive
  directly to author frames and export to Ratatui-friendly formats. Read this
  when the user wants to author interactively or has the MCP connected.
- **chafa** (`references/chafa.md`) — the fastest image→symbols CLI when it's
  installed; recipes for forcing pure half-block (`-f symbols --symbols vhalf`)
  and color/dither control. Optional; the bundled importer covers the no-chafa
  case.
- **TUIStudio** (`references/tui-studio.md`) — a layout/widget composition tool
  (not pixel art). No live API, but a documented `.tui` JSON format and framework
  exporters. Secondary; relevant only when embedding an asset into a larger TUI
  layout.

## Reference implementations to study

`references/reference-implementations.md` dissects real half-block TUI art in the
wild — pixtuoid and rebels-in-the-sky (Ratatui sprite engines), notcurses'
blitter model, the Copilot banner architecture, and a contrasting
full-character-per-pixel NES emulator. Read it for patterns when building
something substantial.

## Runtime integration

- **Runtime-agnostic (default):** the rendered ANSI string from
  `halfblock_render.py` prints in any terminal, with or without a TUI framework.
  This is the most portable target — prefer it unless you're inside a specific
  framework.
- **Ratatui (Rust):** render the grid into a `Buffer` by setting each cell's
  symbol to `▀`/`▄` with per-cell fg/bg `Style`. Full patterns, a reusable
  widget, and the grid-to-Buffer mapping are in **`references/ratatui.md`** —
  this is also what pixtuoid and rebels-in-the-sky do.

> A note on Ink / React-in-the-terminal: ASCII Motion can export Ink components,
> and the Copilot banner used Ink. This skill does not center Ink — prefer the
> runtime-agnostic ANSI path or Ratatui.

## Common pitfalls

- **Baking colors into strings** → can't re-theme or downgrade. Keep a grid +
  renderer.
- **Over-sizing** → huge escape blobs that defeat the "small, embeddable" goal.
  Keep widths small and intentional.
- **Assuming truecolor everywhere** → some terminals don't support it. Offer a
  256/16 downgrade (the renderer does this).
- **Trailing-blank trimming** → transparent cells at line ends can vanish. Use a
  matte, or pad explicitly.
- **Double-width glyphs in art rows** → emoji/CJK break the grid. Keep art to
  block/space glyphs.
- **Animating without synchronized output** → flicker. `preview.py` handles it;
  if you roll your own, wrap frames in `ESC[?2026h … ESC[?2026l`.

## Reference index — read these as needed

- `references/reinterpretation.md` — convert vs. re-interpret, and how to *redraw*
  inspiration art into a small legible asset by hand. *Read when given reference
  art and a tight size budget — the most important call to get right.*
- `references/density-techniques.md` — quadrants, sextants, octants, Braille:
  bit-mappings, when to use each, font/era support. *Read when half-blocks
  aren't dense enough or you need monochrome line art.*
- `references/color-and-dithering.md` — quantization, depth selection, Floyd–
  Steinberg/ordered dithering, choosing 2 colors per cell, transparency. *Read
  when color fidelity or palette reduction matters.*
- `references/animation.md` — frame loops, timing, DECSET 2026, sprite sheets,
  flicker avoidance, players. *Read for any motion.*
- `references/ratatui.md` — grid→Buffer rendering, a reusable widget, immediate-
  mode patterns. *Read when targeting Ratatui.*
- `references/ascii-motion-mcp.md` — the ASCII Motion MCP tool surface and
  recipes for authoring + exporting. *Read when authoring interactively / the MCP
  is connected.*
- `references/chafa.md` — image→symbols CLI recipes. *Read when chafa is
  available and you want the fastest image conversion.*
- `references/tui-studio.md` — `.tui` JSON + exporters. *Read when embedding into
  a larger TUI layout.*
- `references/reference-implementations.md` — annotated real-world half-block
  art. *Read for architecture patterns on bigger builds.*
