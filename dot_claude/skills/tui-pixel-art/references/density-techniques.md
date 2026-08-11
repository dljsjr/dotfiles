# Density Techniques: Beyond Half-Blocks

Half-blocks (1×2 sub-pixels, 2 colors/cell) are the default for colored art.
Reach for these only when you need more spatial resolution and can accept the
trade-offs. **The hard rule across every technique here: a cell can show at most
two colors.** More sub-pixels never means more colors — it means you partition
the same two colors more finely.

The graceful-degradation ladder (from notcurses, the reference implementation):
**octant → sextant → quadrant → half → plain ASCII**, falling back as font/
terminal support drops.

## Contents
- Quadrant blocks (2×2)
- Sextants (2×3)
- Octants (2×4)
- Braille (2×4 dots, monochrome)
- Shade characters (texture)
- Choosing two colors per cell
- Font / terminal support by era

---

## Quadrant blocks — 2×2 per cell

Block Elements (U+2580–U+259F, Unicode 1.0 — **universal support**). The 16
combinations of a 2×2 grid map to these glyphs:

```
space  ▘ U+2598 (TL)   ▝ U+259D (TR)   ▖ U+2596 (BL)   ▗ U+2597 (BR)
▌ U+258C (left)  ▐ U+2590 (right)  ▀ U+2580 (top)  ▄ U+2584 (bottom)
▚ U+259A (TL+BR) ▞ U+259E (TR+BL)  ▙ U+2599  ▟ U+259F  ▛ U+259B  ▜ U+259C  █ U+2588
```

Each of the 4 sub-pixels is a bit. Because fg/bg are swappable (invert the glyph,
swap the colors), you only need the first 8 patterns plus color inversion to
cover all 16. With only two colors available, pick the partition of the 4
sub-pixels into {fg-set, bg-set} that best matches the 4 target colors (see
"Choosing two colors per cell").

**Use when:** you want 2× the horizontal detail of half-blocks and still want
near-universal support. Quadrants are the safest density step up.

---

## Sextants — 2×3 per cell

Symbols for Legacy Computing (U+1FB00–U+1FBFF, **Unicode 13.0, March 2020**). The
60 sextant glyphs are U+1FB00–U+1FB3B, named `BLOCK SEXTANT-n`:

```
U+1FB00 🬀 SEXTANT-1      U+1FB35 🬵 SEXTANT-456     ... etc.
```

A 2×3 grid = 6 sub-pixels = 64 patterns (60 glyphs + space + the 3 reused
half/full blocks). notcurses' `NCBLIT_3x2` uses these and its author found color
loss was less of a problem than expected — "it ended up looking great." chafa:
`--symbols sextant`.

**Use when:** you want higher-res colored art and can require a Unicode-13 font
(most modern terminals on updated systems). The 2×3 cell is a sweet spot for
detailed small sprites.

---

## Octants — 2×4 per cell

Symbols for Legacy Computing **Supplement** (U+1CC00–U+1CEBF, **Unicode 16.0,
September 2024** — very new). The block octants are U+1CD00–U+1CDE5 (230 glyphs;
the other 26 of the 256 patterns already exist as space/half/quadrant/full
blocks).

A 2×4 grid = 8 sub-pixels = 256 patterns. This is the **highest resolution
achievable with characters** (without image protocols). notcurses' `NCBLIT_4x2`
uses octants combined with quadrants and halves.

**Use when:** you want maximum block resolution AND can guarantee a current font
(2024+). Support is still thin — always provide a fallback to sextants/quadrants.

---

## Braille — 2×4 dots per cell (monochrome)

Braille Patterns (U+2800–U+28FF, Unicode 3.0 — widespread, but absent on the
Linux console). All 256 combinations of an 8-dot (2×4) cell. **One color per
cell** (it's a glyph, not fg/bg split), but the densest spatial grid available.

**Bit-mapping** (the dots are numbered irregularly for historical reasons):

```
  col→   left right
 row 1   (1)  (4)      dot1=0x01  dot4=0x08
 row 2   (2)  (5)      dot2=0x02  dot5=0x10
 row 3   (3)  (6)      dot3=0x04  dot6=0x20
 row 4   (7)  (8)      dot7=0x40  dot8=0x80

codepoint = 0x2800 + sum(bit values of raised dots)
```

Example: dots 1, 2, 5 raised → 0x01 + 0x02 + 0x10 = 0x13 → **U+2813** (⠓).
U+2800 is BRAILLE PATTERN BLANK — a fixed-width blank, handy for consistent
spacing.

**Use when:** monochrome line art, plots, charts, curves, or very fine
silhouettes. Braille is the standard for terminal plotting (drawille, etc.).
notcurses notes it "doesn't tend to work out very well for [color] images" —
because it's monochrome. Don't use it for colored sprites; do use it for
single-color detail.

A minimal Braille packer:

```python
# dots: set of (col, row) with col in {0,1}, row in {0,1,2,3}
BRAILLE_BITS = {(0,0):0x01,(0,1):0x02,(0,2):0x04,(1,0):0x08,
                (1,1):0x10,(1,2):0x20,(0,3):0x40,(1,3):0x80}
def braille(dots):
    v = 0
    for d in dots:
        v |= BRAILLE_BITS[d]
    return chr(0x2800 + v)
```

---

## Shade characters — texture, not resolution

```
░ U+2591 LIGHT SHADE     ▒ U+2592 MEDIUM SHADE     ▓ U+2593 DARK SHADE
```

These perceptually blend the fg and bg colors (25% / 50% / 75% fg). They don't
add spatial resolution — they add *apparent intermediate colors* and texture.
Useful for gradients, soft shadows, depth, and dithering between two palette
colors within a cell. See `color-and-dithering.md`.

---

## Choosing two colors per cell

For any technique with N sub-pixels but only 2 output colors, the standard
algorithm (used by chafa and notcurses):

1. For each candidate glyph, it partitions the N sub-pixels into a **fg-set** and
   a **bg-set**.
2. Compute the mean color of each set from the target sub-pixel colors.
3. Measure total squared error between each sub-pixel's target color and its
   set's mean.
4. Pick the (glyph, fg, bg) with the lowest error.

For half-blocks this is trivial (2 sub-pixels → fg=top, bg=bottom, zero error).
The problem only bites at quadrant/sextant/octant density, where you genuinely
lose information squeezing 4–8 colors into 2. That loss is the price of
resolution — and the reason half-blocks remain the best *fidelity-per-color*
choice for colored art.

---

## Support by era (always provide a fallback)

| Technique | Unicode | Year | Support |
|---|---|---|---|
| Half-blocks, quadrants, shades | 1.0 | 1991 | Universal |
| Braille | 3.0 | 1999 | Wide (not Linux console) |
| Sextants | 13.0 | 2020 | Modern fonts |
| Octants | 16.0 | 2024 | New / thin |

When targeting sextants/octants, detect capability or degrade gracefully down the
ladder. The Linux virtual console and old systems (libicu < 66) lack the legacy-
computing blocks entirely — fall back to quadrants/half-blocks there.
