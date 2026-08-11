#!/usr/bin/env python3
"""
image_to_grid.py - convert an image into a half-block grid (the one script here
that needs Pillow).

This is the CONVERSION path: downscale + quantize + (optional) dither an
existing image into a grid, no chafa required. It emits the grid JSON that
halfblock_render.py / preview.py consume.

This is the right tool only when the source is already simple/iconic or the
target is large enough to carry its detail. When the source is detailed and the
target is small (a few cell-rows), conversion produces an unintelligible blob --
do NOT use this; re-interpret instead (redraw by hand). See
references/reinterpretation.md.

KEY DETAIL: half-blocks make SQUARE pixels, so the output pixel grid should
preserve the source aspect ratio directly. Given a target WIDTH in pixels, the
height is round(WIDTH * src_h / src_w). The resulting grid is WIDTH cells wide
and ceil(height/2) cell-rows tall.

KEEP ASSETS SMALL. The whole point of this skill is deliberate, small,
embeddable art. A target width of 24-64 px covers most logos/mascots/headers.
Resist the urge to crank the width to "fit the image" -- that defeats the
purpose and produces huge escape blobs. If you need photographic fidelity at
high resolution, you want an image protocol (sixel/kitty), which is explicitly
out of scope here.

USAGE
-----
    python3 image_to_grid.py logo.png -o logo.json
    python3 image_to_grid.py logo.png --width 40 -o logo.json
    python3 image_to_grid.py logo.png --width 40 --colors 16 --dither floyd -o logo.json
    python3 image_to_grid.py sprite.png --width 24 --nearest --colors 8 -o sprite.json
    python3 image_to_grid.py logo.png --width 32 | python3 halfblock_render.py /dev/stdin

OPTIONS
-------
    --width N         target width in PIXELS (default 32). Height auto from aspect.
    --height N        force height in pixels (otherwise derived from width).
    --colors N        quantize to N colors (palette reduction). Omit to keep full color.
    --dither {none,floyd}
                      dithering when quantizing (default none). Floyd-Steinberg
                      adds texture/gradient fidelity at small palettes but can
                      look noisy on tiny assets -- try both.
    --nearest         use nearest-neighbor downscale (preserve hard pixel edges,
                      good for existing pixel art). Default is smooth (Lanczos).
    --alpha-threshold T
                      pixels with alpha < T (0-255, default 128) become transparent.
    --format {rgb,sprite}
                      output format (default rgb). 'sprite' builds a char palette
                      when the color count is small enough -- nicer to hand-edit.
    -o FILE           write JSON here (default: stdout).

RULE OF THUMB (which knobs for which source)
--------------------------------------------
    Flat / hard-edged sources (logos, icons, pixel art): pass --nearest and skip
    --colors/--dither, so crisp edges and the exact colors survive. The default
    Lanczos resample + median-cut quantization blurs hard edges and shifts flat
    brand colors to muddy tones -- it is for photographic/anti-aliased sources.
    Photographic / gradient sources: keep the default (smooth) resample and add
    --dither floyd.
"""

from __future__ import annotations

import argparse
import json
import sys
from typing import List, Optional, Sequence

try:
    from PIL import Image
except ImportError:  # pragma: no cover
    sys.stderr.write(
        "image_to_grid.py needs Pillow. Install with:\n"
        "    pip install Pillow\n"
        "(The other scripts in this skill are pure stdlib and need nothing.)\n"
    )
    raise

# Characters used to build a sprite palette, in a deliberate order. '.' is
# reserved for transparency. Avoids quotes/backslash/space and other awkward
# chars so the JSON stays clean and the rows stay readable.
_PALETTE_CHARS = (
    "Oo#*+=-:xX%@ABCDEFGHJKLMNPQRSTUVWYZabcdefghijkmnpqrstuvwyz0123456789"
)
# Each char must be distinct: a sprite maps exactly one color per char, so a
# duplicate would silently collapse two colors into one on a round-trip.
assert len(set(_PALETTE_CHARS)) == len(_PALETTE_CHARS), \
    "image_to_grid: _PALETTE_CHARS must contain unique characters"

# Pillow moved the dither/quantize enums under Image.Dither / Image.Quantize in
# v9.1; older versions exposed bare ints. Resolve once here, with fallbacks.
_DITHER = getattr(Image, "Dither", Image)
_QUANT = getattr(Image, "Quantize", Image)
_DITHER_FS = getattr(_DITHER, "FLOYDSTEINBERG", 3)
_DITHER_NONE = getattr(_DITHER, "NONE", 0)
_QUANT_MEDIANCUT = getattr(_QUANT, "MEDIANCUT", 0)


def _derive_size(src_w: int, src_h: int, width: Optional[int],
                 height: Optional[int]) -> tuple[int, int]:
    if width is None:
        width = 32
    if height is None:
        height = max(1, round(width * src_h / src_w))
    return width, height


def convert(
    path: str,
    width: Optional[int] = None,
    height: Optional[int] = None,
    colors: Optional[int] = None,
    dither: str = "none",
    nearest: bool = False,
    alpha_threshold: int = 128,
    out_format: str = "rgb",
) -> dict:
    image = Image.open(path).convert("RGBA")
    tw, th = _derive_size(image.width, image.height, width, height)
    resample = Image.NEAREST if nearest else Image.LANCZOS
    image = image.resize((tw, th), resample=resample)

    alpha = image.getchannel("A")
    rgb = image.convert("RGB")

    if colors:
        dmode = _DITHER_FS if dither == "floyd" else _DITHER_NONE
        # Pillow ignores `dither` when it generates an adaptive palette in the
        # same quantize() call (the MEDIANCUT path), so `--dither floyd` would
        # silently do nothing. To actually dither, build the adaptive palette
        # first, then remap the image ONTO that palette with dithering enabled
        # -- that second call is where the dither setting takes effect.
        try:
            pal = rgb.quantize(colors=colors, method=_QUANT_MEDIANCUT)
            q = rgb.quantize(colors=colors, method=_QUANT_MEDIANCUT,
                             palette=pal, dither=dmode)
        except TypeError:
            # Very old Pillow: limited signature without palette/dither support.
            q = rgb.quantize(colors=colors)
        rgb = q.convert("RGB")

    rpx = rgb.load()
    apx = alpha.load()

    grid: List[List[Optional[List[int]]]] = []
    for y in range(th):
        row: List[Optional[List[int]]] = []
        for x in range(tw):
            if apx[x, y] < alpha_threshold:
                row.append(None)
            else:
                r, g, b = rpx[x, y]
                row.append([r, g, b])
        grid.append(row)

    if out_format == "sprite":
        sprite = _to_sprite(grid)
        if sprite is not None:
            return sprite
        sys.stderr.write(
            "[note] too many distinct colors for a sprite palette; "
            "emitting rgb format instead\n"
        )

    return {"width": tw, "height": th, "pixels": grid}


def _to_sprite(grid) -> Optional[dict]:
    """Build a sprite-format object if the distinct color count fits the
    available palette characters; otherwise return None."""
    colors: dict = {}
    order: List[Optional[tuple]] = []
    for row in grid:
        for px in row:
            key = None if px is None else tuple(px)
            if key not in colors:
                colors[key] = None
                order.append(key)
    distinct_opaque = [k for k in order if k is not None]
    if len(distinct_opaque) > len(_PALETTE_CHARS):
        return None

    palette: dict = {".": None}
    char_for: dict = {None: "."}
    ci = 0
    for key in distinct_opaque:
        ch = _PALETTE_CHARS[ci]
        ci += 1
        char_for[key] = ch
        palette[ch] = list(key)

    rows = []
    for row in grid:
        rows.append("".join(char_for[None if px is None else tuple(px)]
                            for px in row))
    return {"palette": palette, "rows": rows}


def _dims(obj: dict) -> tuple[int, int]:
    """(width, height) in pixels for either output format, for the size report."""
    if "pixels" in obj:
        return obj["width"], obj["height"]
    rows = obj.get("rows", [])
    return (len(rows[0]) if rows else 0), len(rows)


def main(argv: Optional[Sequence[str]] = None) -> int:
    ap = argparse.ArgumentParser(description="Convert an image to a half-block grid.")
    ap.add_argument("path", help="input image (png, jpg, ...)")
    ap.add_argument("--width", type=int, default=None, help="target width in pixels")
    ap.add_argument("--height", type=int, default=None, help="force height in pixels")
    ap.add_argument("--colors", type=int, default=None, help="quantize to N colors")
    ap.add_argument("--dither", choices=["none", "floyd"], default="none")
    ap.add_argument("--nearest", action="store_true",
                    help="nearest-neighbor downscale (hard edges)")
    ap.add_argument("--alpha-threshold", type=int, default=128)
    ap.add_argument("--format", choices=["rgb", "sprite"], default="rgb",
                    dest="out_format")
    ap.add_argument("-o", "--output", default=None, help="output JSON path")
    args = ap.parse_args(argv)

    obj = convert(
        args.path,
        width=args.width,
        height=args.height,
        colors=args.colors,
        dither=args.dither,
        nearest=args.nearest,
        alpha_threshold=args.alpha_threshold,
        out_format=args.out_format,
    )
    text = json.dumps(obj)
    if args.output:
        with open(args.output, "w", encoding="utf-8") as fh:
            fh.write(text + "\n")
        w, h = _dims(obj)
        sys.stderr.write(f"[wrote {args.output}: {w}x{h} px]\n")
    else:
        sys.stdout.write(text + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
