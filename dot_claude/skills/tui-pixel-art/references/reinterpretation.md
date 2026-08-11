# Re-interpreting Reference Art (Redrawing, Not Converting)

There are two ways to turn reference art into a terminal asset, and conflating
them is the most common way to get garbage.

- **Convert** = mechanically downscale + quantize + dither the source. Faithful
  signal processing. The bundled tools already do this well
  (`scripts/image_to_grid.py`, or chafa). Use it when it's the right mode (below).
- **Re-interpret** = *you redraw* the subject at the target size, deciding what
  to keep, what to drop, and how to suggest detail with a few pixels. This is
  authoring with judgment, not a filter — there is no binary for it, and that's
  exactly why it's the valuable part of this skill.

**This document is about re-interpretation.** Conversion is covered by the
importer and `chafa.md`.

## Decide the mode first

| Situation | Mode |
|---|---|
| Source is already simple / iconic / high-contrast (a flat logo, an existing sprite, a bold mark) | **Convert** |
| Target is large enough to carry the source's detail (roughly ≥ 32×32 px) | **Convert** |
| Source is detailed / photographic / busy **and** target is small (a handful of cell-rows) | **Re-interpret** |
| You want a stylized asset that captures an *essence* or *vibe*, not a faithful copy | **Re-interpret** |

The tell-tale that you should have re-interpreted: the converted output is a
muddy, noisy blob, the silhouette is unreadable, and dithering made it worse, not
better. Downsampling can't *abstract* — it can only average. At a small cell
budget, averaging a rich image destroys the very features that made it
recognizable. Stop converting and redraw.

## Re-interpretation is something you do, not something you run

You are multimodal — you can look at the inspiration, understand what it *is*,
and author the grid directly in the sprite format. The scripts in this skill are
for **checking** your redraw (`halfblock_render.py --ascii` for silhouette,
`preview.py` for motion), not for producing it. The deliverable comes out of your
judgment.

## The method

1. **Read the inspiration.** Before drawing, name:
   - the **silhouette** / overall shape,
   - the **2–4 features that make it recognizable** (the "read" — e.g. a dragon's
     long neck + wings; a fox's pointed ears + bushy tail),
   - the **color identity** (3–6 colors that carry the vibe),
   - the **pose / attitude / gesture**,
   - the **single most iconic element** (if you keep one thing, this is it).

2. **Set the cell budget.** Width × cell-rows (1 cell-row = 2 px). The smaller the
   budget, the more ruthless the abstraction. A "12-row" asset is 24 px tall —
   that's enough for a clear character but not for texture or fine detail.
   **Author 2 pixel-rows per cell-row**: the classic mistake is drawing a
   "10-row" asset only 10 px tall instead of 20. `halfblock_render.py` prints a
   `[W×H px → cells]` header — check its cell numbers match your budget.

3. **Silhouette first.** Block the shape so it reads in pure monochrome. Check
   with `halfblock_render.py --ascii`: if the silhouette doesn't read as the
   subject with zero color, no amount of color will save it. Iterate the outline
   until it's unmistakable.

4. **Place only the identifying features.** Add the few elements that carry
   recognition — and stop. At small sizes, *removing* detail almost always
   improves the read. One well-placed pixel can be an eye; two can be a beak.
   Resist transcribing the source.

5. **Choose a deliberate palette — edit, don't copy.** Start from the source's
   colors but adjust for legibility: raise contrast, drop muddy mid-tones, make
   sure the subject separates from whatever's behind it, and decide whether it
   must survive a 16-color downgrade (`color-and-dithering.md`). If two roles
   would collapse at 16-color (e.g. body and outline both → red), either pick a
   hue/lightness pair that survives the 16-color cube, or accept the merge and
   note which depth the asset is tuned for. The palette can *intentionally
   diverge* from the source — a downsampler must use the source's averaged
   colors; you don't. Fewer, punchier colors read better.

6. **Imply form with minimal shading.** One shadow color and one highlight are
   usually enough to suggest volume. Use shade glyphs (░▒▓) sparingly for soft
   transitions. Don't dither tiny assets — the texture competes with the
   silhouette (noise vs. signal).

7. **Exaggerate what identifies the subject.** This is caricature, not
   reproduction. Make the defining feature larger and clearer than "accurate" —
   the big ears, the long tail, the sharp beak. Recognition beats fidelity.

8. **Iterate by squinting.** Render in color, step back (or blur mentally), and
   ask "does this read as the subject at a glance?" Cut, sharpen, repeat. The
   `--ascii` silhouette and a quick `preview.py` look are your feedback loop.

## Using the inspiration as reference (the honest, small role of conversion)

It's fine to mechanically downscale the inspiration **for yourself** — to sample
its colors and to *see why conversion fails* at this size. Just don't ship that
output. If you want the source's exact colors as a starting reference, a throwaway
snippet is enough (you'll still edit the palette for legibility):

```python
from PIL import Image
from collections import Counter
im = Image.open("inspo.png").convert("RGB").resize((24, 24))   # ~target scale
q = im.quantize(colors=6)
pal = q.getpalette()
top = Counter(q.getdata()).most_common(6)
print([(pal[i*3], pal[i*3+1], pal[i*3+2]) for i, _ in top])    # reference only
```

That's a *reference*, not a deliverable. The asset still comes from your hand. A
blank canvas to draw into is just a sprite with transparent rows — emit one
directly at your target size; you don't need a tool for that.

No global Pillow? Run the snippet with `uv run --with pillow python3 - <<'PY' …
PY`, or get the same "see why it blobs" downscale from `chafa -f symbols
--symbols half --size W×H inspo.png` (see `chafa.md`). Either way it's a check,
not the deliverable.

## Worked sketch

Inspiration: a detailed, painterly illustration of a red dragon. Target: 12×10
cells (24×20 px).

- **Read:** silhouette = long S-neck + two wings + tail; identifying features =
  wing membranes, a single eye, the neck curve; color identity = body red, darker
  red shadow, membrane orange, one highlight; iconic element = the spread wings.
- **Redraw:** block the S-neck-plus-wings silhouette (check `--ascii` — does it
  say "dragon"?). Add the wing-membrane color as flat panels, one eye pixel, a
  shadow under the jaw and along the belly, one highlight on the back. **Drop**
  scales, individual claws, background, gradients — none of it survives 24 px and
  all of it muddies the read.
- **Palette:** 4–5 colors, contrast pushed so the dragon pops on any background;
  pick reds that don't collapse to the same gray in 16-color if portability
  matters.

A downsample of the painting at 24 px would be a reddish smear. The redraw reads
as a dragon instantly — because you made choices a filter can't.
