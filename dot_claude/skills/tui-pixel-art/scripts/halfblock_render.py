#!/usr/bin/env python3
"""
halfblock_render.py - runtime-agnostic vertical half-block renderer.

THE CORE IDEA
-------------
A terminal cell shows ONE glyph with ONE foreground and ONE background color.
Print U+2580 "UPPER HALF BLOCK" and the foreground paints the TOP half of the
cell while the background paints the BOTTOM half -- two independently colored,
roughly square pixels stacked in a single character cell. To draw a bitmap you
walk the pixel grid two rows at a time: pixel row 2N -> foreground (top),
pixel row 2N+1 -> background (bottom).

    fg = top pixel  ->  upper half  ┐
                                     ├─ one cell: "▀" with SGR fg + bg
    bg = bottom pixel -> lower half ┘

Because terminal cells are ~2x taller than wide, a 1x2 split yields ~square
pixels and the art keeps its proportions. (Rendering one full character per
pixel instead would stretch everything 2x vertically -- that is the whole
reason this technique exists.)

WHY ZERO DEPENDENCIES
---------------------
This module is pure standard library on purpose. The renderer and any art it
draws should be embeddable in any project without dragging in Pillow/numpy.
Image *import* (PNG -> grid) needs Pillow, so it lives separately in
image_to_grid.py. Animation playback lives in preview.py. This file does one
thing: turn a grid of colors into half-block text.

DATA MODEL
----------
A "grid" is a 2D list, row-major, where each pixel is either:
  - None                      -> transparent (terminal background shows through)
  - (r, g, b)  ints 0..255    -> an opaque color

Two JSON authoring formats are accepted (see load_grid):

1. SPRITE format (human-authorable, great for hand-drawn assets):
   {
     "palette": {".": null, "O": [215,119,87], "k": [40,30,25]},
     "rows": ["..OO..", ".OOOO.", "OOkkOO"]
   }
   Each character in each row indexes the palette. "rows" must all be the same
   length. This is the recommended format for embeddable assets: it reads like
   pixel art in source and diffs cleanly.

2. RGB format (what image_to_grid.py emits):
   {"width": W, "height": H, "pixels": [[[r,g,b], null, ...], ...]}

LIBRARY USE
-----------
    from halfblock_render import load_grid, render
    grid = load_grid("mascot.json")
    print(render(grid, color="truecolor"))   # -> str with ANSI escapes

CLI USE
-------
    python3 halfblock_render.py mascot.json                 # truecolor
    python3 halfblock_render.py mascot.json --color 256     # 256-color downgrade
    python3 halfblock_render.py mascot.json --color 16      # 16-color downgrade
    python3 halfblock_render.py mascot.json --ascii         # color-blind shape check

The --ascii preview maps each pixel to a brightness glyph instead of color, so
you can verify the SILHOUETTE of an asset in a plain log (no color needed). Use
it to sanity-check shape when you cannot see terminal color.
"""

from __future__ import annotations

import argparse
import json
import sys
from typing import List, Optional, Sequence, Tuple

Pixel = Optional[Tuple[int, int, int]]
Grid = List[List[Pixel]]

UPPER = "\u2580"  # ▀ top half painted by fg, bottom half by bg
LOWER = "\u2584"  # ▄ used when only the bottom pixel is set (top transparent)
RESET = "\x1b[0m"


# --------------------------------------------------------------------------- #
# Grid loading / parsing
# --------------------------------------------------------------------------- #

def _coerce_pixel(value) -> Pixel:
    """Normalize one palette/grid entry into a Pixel (None or (r,g,b))."""
    if value is None:
        return None
    if isinstance(value, str):
        s = value.lstrip("#")
        if len(s) == 6:
            try:
                return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16))
            except ValueError:
                raise ValueError(f"bad hex color: {value!r}") from None
        raise ValueError(f"bad hex color: {value!r}")
    if isinstance(value, (list, tuple)) and len(value) == 3:
        r, g, b = value
        return (int(r), int(g), int(b))
    raise ValueError(f"cannot interpret color: {value!r}")


def parse_grid(obj: dict) -> Grid:
    """Turn a parsed-JSON sprite or rgb object into a Grid."""
    if "rows" in obj and "palette" in obj:
        palette = {k: _coerce_pixel(v) for k, v in obj["palette"].items()}
        rows = obj["rows"]
        if not rows:
            return []
        width = len(rows[0])
        grid: Grid = []
        for y, row in enumerate(rows):
            if len(row) != width:
                raise ValueError(
                    f"row {y} has width {len(row)}, expected {width} "
                    f"(all rows must be the same length)"
                )
            try:
                grid.append([palette[ch] for ch in row])
            except KeyError as e:
                raise ValueError(
                    f"row {y} uses undefined palette char {e.args[0]!r}"
                ) from None
        return grid
    if "pixels" in obj:
        return [[_coerce_pixel(p) for p in row] for row in obj["pixels"]]
    raise ValueError(
        "unrecognized grid object: need either {'palette','rows'} or {'pixels'}"
    )


def load_grid(path: str) -> Grid:
    with open(path, "r", encoding="utf-8") as fh:
        return parse_grid(json.load(fh))


def grid_dimensions(grid: Grid) -> Tuple[int, int]:
    """Return (width_in_pixels, height_in_pixels)."""
    h = len(grid)
    w = max((len(r) for r in grid), default=0)
    return w, h


# --------------------------------------------------------------------------- #
# Color downgrade: truecolor -> 256 -> 16
# --------------------------------------------------------------------------- #
# These let one authored asset render acceptably across terminals. Truecolor is
# brand-accurate but unsupported on some terminals and ignores user themes;
# 16-color is remapped by the user's theme (good for accessibility, not for
# exact hues). Pick the mode that fits where the asset will live.

_CUBE = [0x00, 0x5F, 0x87, 0xAF, 0xD7, 0xFF]  # xterm 6x6x6 cube levels


def _nearest_cube_component(v: int) -> int:
    best_i, best_d = 0, 1 << 30
    for i, level in enumerate(_CUBE):
        d = (v - level) ** 2
        if d < best_d:
            best_i, best_d = i, d
    return best_i


def _rgb_to_256(r: int, g: int, b: int) -> int:
    # Candidate 1: nearest color cube entry.
    ri, gi, bi = (_nearest_cube_component(c) for c in (r, g, b))
    cube_rgb = (_CUBE[ri], _CUBE[gi], _CUBE[bi])
    cube_idx = 16 + 36 * ri + 6 * gi + bi
    cube_d = sum((a - c) ** 2 for a, c in zip((r, g, b), cube_rgb))
    # Candidate 2: nearest grayscale ramp entry (232..255).
    gray = round((r + g + b) / 3)
    gi2 = min(23, max(0, round((gray - 8) / 10)))
    gray_level = 8 + 10 * gi2
    gray_idx = 232 + gi2
    gray_d = sum((a - gray_level) ** 2 for a in (r, g, b))
    return cube_idx if cube_d <= gray_d else gray_idx


# Standard xterm 16-color palette (index -> rgb). Real values vary by theme;
# we pick the nearest by intent. 0-7 -> SGR 30-37/40-47, 8-15 -> 90-97/100-107.
_ANSI16 = [
    (0, 0, 0), (205, 0, 0), (0, 205, 0), (205, 205, 0),
    (0, 0, 238), (205, 0, 205), (0, 205, 205), (229, 229, 229),
    (127, 127, 127), (255, 0, 0), (0, 255, 0), (255, 255, 0),
    (92, 92, 255), (255, 0, 255), (0, 255, 255), (255, 255, 255),
]


def _rgb_to_16(r: int, g: int, b: int) -> int:
    best_i, best_d = 0, 1 << 30
    for i, (cr, cg, cb) in enumerate(_ANSI16):
        d = (r - cr) ** 2 + (g - cg) ** 2 + (b - cb) ** 2
        if d < best_d:
            best_i, best_d = i, d
    return best_i


# --------------------------------------------------------------------------- #
# SGR (escape-sequence) generation with run-length minimization
# --------------------------------------------------------------------------- #

def _fg_seq(px: Pixel, color: str) -> str:
    if px is None:
        return "39"  # default foreground
    r, g, b = px
    if color == "truecolor":
        return f"38;2;{r};{g};{b}"
    if color == "256":
        return f"38;5;{_rgb_to_256(r, g, b)}"
    if color == "16":
        idx = _rgb_to_16(r, g, b)
        return str(30 + idx if idx < 8 else 90 + (idx - 8))
    raise ValueError(f"unknown color mode: {color}")


def _bg_seq(px: Pixel, color: str) -> str:
    if px is None:
        return "49"  # default background (transparent)
    r, g, b = px
    if color == "truecolor":
        return f"48;2;{r};{g};{b}"
    if color == "256":
        return f"48;5;{_rgb_to_256(r, g, b)}"
    if color == "16":
        idx = _rgb_to_16(r, g, b)
        return str(40 + idx if idx < 8 else 100 + (idx - 8))
    raise ValueError(f"unknown color mode: {color}")


def render_lines(
    grid: Grid,
    color: str = "truecolor",
    matte: Pixel = None,
) -> List[str]:
    """Render a grid to a list of line strings (no trailing newline per line).

    color: "truecolor" | "256" | "16"
    matte: if given, transparent pixels are composited onto this color instead
           of showing the terminal background. Use a matte when the host strips
           trailing blanks or when you need a known backdrop; leave None for
           true transparency.

    Returned lines already contain a trailing RESET so colors never bleed.
    Pairs of pixel rows collapse into one text line. An odd final row renders
    with UPPER + fg only (its phantom bottom row is treated as transparent).
    """
    if matte is not None:
        grid = [[(px if px is not None else matte) for px in row] for row in grid]

    width, height = grid_dimensions(grid)
    lines: List[str] = []

    def get(y: int, x: int) -> Pixel:
        if 0 <= y < len(grid) and x < len(grid[y]):
            return grid[y][x]
        return None

    for top_y in range(0, height, 2):
        bot_y = top_y + 1
        out: List[str] = []
        cur_fg: Optional[str] = None
        cur_bg: Optional[str] = None
        for x in range(width):
            top = get(top_y, x)
            bot = get(bot_y, x)

            # Choose glyph + which color goes to fg vs bg so that a half-
            # transparent cell keeps the terminal background on the empty side.
            if top is None and bot is None:
                glyph, fg, bg = " ", None, None
            elif bot is None:
                glyph, fg, bg = UPPER, top, None            # top only
            elif top is None:
                glyph, fg, bg = LOWER, bot, None            # bottom only
            else:
                glyph, fg, bg = UPPER, top, bot             # both

            fg_seq = _fg_seq(fg, color)
            bg_seq = _bg_seq(bg, color)
            if fg_seq != cur_fg or bg_seq != cur_bg:
                out.append(f"\x1b[{fg_seq};{bg_seq}m")
                cur_fg, cur_bg = fg_seq, bg_seq
            out.append(glyph)
        out.append(RESET)
        lines.append("".join(out))
    return lines


def render(grid: Grid, color: str = "truecolor", matte: Pixel = None) -> str:
    """Render a grid to a single newline-joined string."""
    return "\n".join(render_lines(grid, color=color, matte=matte))


# --------------------------------------------------------------------------- #
# Plain-ASCII silhouette preview (no color) -- for shape verification in logs
# --------------------------------------------------------------------------- #

_RAMP = " .:-=+*#%@"  # dark -> light


def render_ascii(grid: Grid) -> str:
    """Map each pixel to a brightness glyph. One char per pixel (NOT half-block),
    so the output is 2x tall but lets you read the silhouette with no color."""
    lines = []
    width, height = grid_dimensions(grid)
    for y in range(height):
        row = []
        for x in range(width):
            px = grid[y][x] if x < len(grid[y]) else None
            if px is None:
                row.append(" ")
            else:
                lum = (0.299 * px[0] + 0.587 * px[1] + 0.114 * px[2]) / 255.0
                row.append(_RAMP[min(len(_RAMP) - 1, int(lum * len(_RAMP)))])
        lines.append("".join(row))
    return "\n".join(lines)


# --------------------------------------------------------------------------- #
# CLI
# --------------------------------------------------------------------------- #

def main(argv: Optional[Sequence[str]] = None) -> int:
    ap = argparse.ArgumentParser(description="Render a grid as Unicode half-blocks.")
    ap.add_argument("path", help="path to a sprite or rgb JSON grid")
    ap.add_argument(
        "--color",
        choices=["truecolor", "256", "16"],
        default="truecolor",
        help="color depth (default: truecolor)",
    )
    ap.add_argument(
        "--matte",
        default=None,
        help="hex color (e.g. 1e1e2e) to composite transparency onto",
    )
    ap.add_argument(
        "--ascii",
        action="store_true",
        help="print a no-color brightness silhouette instead (shape check)",
    )
    args = ap.parse_args(argv)

    # Bad input (malformed JSON, mismatched row widths, an undefined palette
    # char, bad hex, a missing file) is a normal hand-authoring mistake -- report
    # it as a one-line message, not a multi-line Python traceback.
    try:
        grid = load_grid(args.path)
        if args.ascii:
            print(render_ascii(grid))
            return 0
        matte = _coerce_pixel(args.matte) if args.matte else None
        w, h = grid_dimensions(grid)
        sys.stdout.write(render(grid, color=args.color, matte=matte) + "\n")
    except (ValueError, KeyError, OSError, json.JSONDecodeError) as e:
        sys.stderr.write(f"error: {e}\n")
        return 2
    sys.stderr.write(
        f"[{w}x{h} px  ->  {w} cells wide x {-(-h // 2)} cells tall  "
        f"({args.color})]\n"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
