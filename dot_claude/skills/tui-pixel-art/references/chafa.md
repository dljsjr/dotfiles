# chafa — Image → Symbols CLI

`chafa` (hpjansson/chafa) is the most complete terminal-graphics tool and the
fastest path to convert an image to Unicode symbol art **when it's installed**.
The bundled `image_to_grid.py` covers the no-chafa case; use chafa when it's
available and you want its superior symbol selection and dithering.

> chafa auto-detects and will use **Sixel/Kitty/iTerm2** if your terminal
> supports them. This skill is Unicode-only, so **force symbol mode** with
> `-f symbols`. Never rely on chafa's default format detection for this skill.

## Install

```
# Debian/Ubuntu: apt install chafa     macOS: brew install chafa
chafa --version
```

## The half-block recipe (this skill's default)

```bash
# Pure vertical half-block, small, truecolor:
chafa -f symbols --symbols vhalf -c full --size 40x20 logo.png

# Force half-block + keep it small + 256-color for portability:
chafa -f symbols --symbols vhalf -c 256 --size 32x16 logo.png
```

`--symbols vhalf` restricts output to vertically-split half-blocks — the set
`▀` U+2580 (upper), `▄` U+2584 (lower), `█` U+2588 (full), and space — which is
exactly the technique this skill centers. (In practice chafa emits mostly `▄`,
painting the cell as bg-over-fg.) Other symbol classes trade fidelity for
density.

## Key flags

| Flag | Purpose |
|---|---|
| `-f, --format symbols` | **force Unicode symbol art** (not sixel/kitty) |
| `--symbols CLASS` | which glyphs: `vhalf`, `half`, `quad`, `sextant`, `block`, `border`, `braille`, `ascii`, `solid`, `stipple`, `legacy`, `wedge`, `all`, `none`, `+`/`-` to combine |
| `-c, --colors none\|2\|8\|16/8\|16\|240\|256\|full` | color depth (chafa recommends `240` over `256`: the low 16 are unreliable across terminals; `16/8` = 16 fg / 8 bg for old terminals) |
| `--color-space rgb\|din99d` | `din99d` = smoother gradients |
| `--size WxH` | bound output to cells (keep it SMALL) |
| `--dither ordered\|diffusion\|none` | dithering mode |
| `--dither-grain WxH` | dither cell size |
| `--fg` / `--bg` | set fg/bg colors |
| `--symbols sextant` / `legacy` / `wedge` | higher-density legacy-computing glyphs |

## Density variants

```bash
chafa -f symbols --symbols quad     -c 256 --size 40x20 img.png   # 2x2
chafa -f symbols --symbols sextant  -c 256 --size 40x20 img.png   # 2x3 (Unicode 13)
chafa -f symbols --symbols braille  -c 16  --size 40x20 img.png   # 2x4 mono line art
```

See `density-techniques.md` for what each is good for and the support caveats.

## Getting chafa output into an asset

chafa emits a ready-to-print ANSI string, not the skill's grid JSON. Two paths:

- **Use it as-is:** capture the string and `print` it (runtime-agnostic), or drop
  it into a Ratatui `Text`/`Paragraph` (it already carries SGR codes).
- **Reconstruct a grid:** if you need a re-themeable grid, prefer authoring with
  `image_to_grid.py` (which emits the grid format directly) over parsing chafa's
  output. Use chafa for quick conversion/preview; use the bundled importer when
  you want the editable grid.

chafa is also embeddable as **libchafa** (C), and `ratatui-image` can link it —
relevant only if you're building a converter, not authoring a single asset.

## Animated GIFs

```bash
chafa -f symbols --symbols vhalf -c 256 anim.gif   # plays the GIF in symbol mode
```

For embeddable animation, prefer authoring frames (ASCII Motion) or exporting a
frame array; chafa's GIF playback is for viewing, not embedding.
