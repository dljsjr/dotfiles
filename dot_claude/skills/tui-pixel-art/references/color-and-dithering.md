# Color, Quantization, and Dithering

How to get good color out of a two-colors-per-cell medium. The bundled scripts
implement the depth downgrades and image quantization; this explains the choices
so you use them well.

## Color depth: pick by where the asset lives

| Depth | Escape | Pros | Cons |
|---|---|---|---|
| **Truecolor (24-bit)** | `38;2;r;g;b` / `48;2;r;g;b` | exact, brand-accurate | unsupported on some terminals; ignores user themes |
| **256-color** | `38;5;n` / `48;5;n` | wide support; handles browns/oranges | a fixed palette; slight shifts |
| **16-color (4-bit)** | `30–37` / `40–47`, bright `90–97` / `100–107` | universal; **user-themeable** (accessibility) | no brown/orange; approximates everything |

Reset: `ESC[0m` (all) or `ESC[39;49m` (just fg/bg).

**Rule of thumb:** if the asset ships in a CLI that others will theme or that
must be accessible, target **16-color with semantic roles** (so the user's theme
recolors it). If you control the terminal and want brand-exact color, use
**truecolor**. **256** is the safe middle. The renderer's `--color` flag
downgrades a single authored asset to any of these.

Why 16-color drops orange: the 16-color palette has no brown/orange entry, so
nearest-color mapping sends orange to gray. This is *correct* behavior, not a
bug. Design orange/brown art in 256/truecolor, or choose a role that maps to a
themeable slot you control.

## Quantization (palette reduction)

To target a small palette, reduce the image's colors first. Algorithms:
median-cut (what Pillow's `quantize` uses by default), k-means, octree. The
bundled `image_to_grid.py --colors N` does median-cut quantization to N colors.

Small palettes (4–8 colors) are not just a size win — they make small art
**read** better (clear flat regions instead of noisy gradients). Prefer a
deliberate small palette over "as many colors as the source has."

## Dithering

Dithering fakes intermediate colors by patterning the available ones. Two
families:

**Error diffusion** — Floyd–Steinberg (1976) and relatives (Atkinson, Stucki,
Sierra, Burkes, JJN). Pushes each pixel's quantization error onto neighbors.
Floyd–Steinberg weights: 7/16 right, 3/16 below-left, 5/16 below, 1/16
below-right. Atkinson diffuses only 6/8 of the error → higher contrast, the
classic early-Mac look. **Best for:** photos, gradients, organic texture.
`image_to_grid.py --dither floyd`.

**Ordered / Bayer** — a fixed recursive threshold matrix (2×2, 4×4, 8×8). Cheap,
deterministic, tileable, "retro" feel. **Best for:** sprites, UI textures,
backgrounds where you want a stable pattern.

**Caution at small sizes:** dithering can look *noisy* on tiny assets — the
texture competes with the silhouette. On a 16×16 mascot, flat colors usually
read better than dithered ones. Try both; for logos/sprites, often skip
dithering; for small *photos*/gradients, Floyd–Steinberg helps. Pair the
**resample filter** with the source too: hard-edged / flat art (logos, icons,
pixel sprites) wants `--nearest` to keep edges crisp, while photographic sources
want the smooth default. chafa exposes `--dither ordered|diffusion` and
`--dither-grain`.

## Choosing the best two colors per cell

When a technique gives more than 2 sub-pixels per cell (quadrants, sextants,
octants), you must collapse their colors to two — the standard lowest-squared-
error partition. The full algorithm lives in `density-techniques.md` >
"Choosing two colors per cell" (the canonical copy). The key takeaway for color
work: half-blocks are the lossless case (top→fg, bottom→bg, zero error), which
is why they give the best fidelity-per-color; the loss only bites at
quadrant/sextant/octant density.

Perceptual color spaces help the nearest-color and error math: chafa's
`--color-space din99d` produces smoother gradients than raw RGB distance. For
small art, plain RGB distance (what the bundled scripts use) is usually fine; if
gradients band badly, that's the lever.

## Transparency

Terminals have no true alpha. Options:

1. **True transparency** — leave the empty side at the default background
   (`ESC[49m`); the terminal's own background shows through. The bundled renderer
   does this: a half-transparent cell uses `▀`/`▄` with fg only, a fully empty
   cell is a space. `image_to_grid.py` turns source alpha below a threshold into
   transparent pixels.
2. **Matte** — composite transparency onto a chosen backdrop color. Use when you
   need a known background or when the host strips trailing blanks (a real bug:
   transparent cells at line ends can vanish). The renderer's `--matte HEX`
   composites onto that color. A production trick is emitting transparent cells as
   background-colored spaces so hosts don't trim them.

Choose true transparency for assets that sit on varied backgrounds; choose a
matte when you control the backdrop or need trim-safety.
