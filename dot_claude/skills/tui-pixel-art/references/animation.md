# Animating Half-Block Art

Terminal animation is frame-based: store frames, repaint on a timer. The bundled
`scripts/preview.py` already implements a correct player; read this to understand
the model, to build your own loop (e.g. inside a Ratatui app), and to get the
flicker and timing details right.

## Contents
- The frame loop
- Synchronized output (DECSET 2026) — the flicker fix
- Cursor control sequences
- Timing and frame rates
- The animation data model
- Sprite sheets
- Avoiding flicker (beyond 2026)
- Players and libraries
- Accessibility

---

## The frame loop

The minimal loop: render frame → position cursor → write → sleep → repeat.

```
hide cursor
for each frame (looping):
    BEGIN synchronized update      (ESC[?2026h)
    move cursor to art's top-left  (ESC[{n}A or ESC[{row};{col}H)
    write the rendered frame lines
    END synchronized update        (ESC[?2026l)
    sleep(frame_duration)
on exit: show cursor
```

Repaint **in place** (move the cursor up N lines and overwrite) rather than
clearing the whole screen — less work, less flicker, and the animation stays
inline. Only clear the full screen for full-screen scenes.

## Synchronized output (DECSET 2026) — the flicker fix

This is the single most important technique. Wrap each frame's writes in:

```
ESC[?2026h   ... all writes for this frame ...   ESC[?2026l
   BSU  (begin synchronized update)        ESU  (end synchronized update)
```

The terminal buffers everything between BSU and ESU and applies it **atomically**
— you never see a half-drawn frame, and the cursor doesn't visibly jump.
Terminals that don't understand 2026 ignore the sequences, so it is always safe
to emit unconditionally.

Detect support if you want to branch (DECRQM query):

```
ESC[?2026$p
```

A reply of `;1` (set) or `;2` (reset) means the mode is recognized → 2026 is
usable; `;0` (not recognized) or no reply means unsupported; `;4` (permanently
reset) means recognized but disabled and not enableable.

**Support:** Windows Terminal, iTerm2, Alacritty, kitty, foot, WezTerm, Contour,
xterm.js, and tmux 3.4+ (passthrough: `set -as terminal-features ',xterm*:sync'`).
Real-world note: Claude Code itself had flicker bugs in tmux traced precisely to
*not* emitting DECSET 2026 around its renders. Don't skip it.

## Cursor control sequences

```
ESC[?25l            hide cursor
ESC[?25h            show cursor
ESC[H               cursor to home (1,1)
ESC[{row};{col}H    cursor to absolute position
ESC[{n}A            cursor up n lines      (in-place repaint)
ESC[{n}B / C / D    down / right / left
\r                  carriage return (column 0)
ESC[2K              clear entire line
ESC[J  / ESC[0J     clear to end of screen
ESC[2J              clear whole screen
```

In-place repaint pattern: after printing a frame of height `H`, the next frame
emits `ESC[{H}A` + `\r`, then reprints each line preceded by `ESC[2K` to wipe
leftovers. (This is exactly what `preview.py` does.)

## Timing and frame rates

- **~10–15 fps** is typical and safe. `preview.py` defaults to per-frame
  durations from a global `fps`.
- **Pick the rate for the motion.** Spinners and loaders read fine slower
  (~8–10 fps — calmer, even); reserve ~12–15 fps for motion that must feel smooth
  (walk cycles, scrolls). Below ~6 fps looks choppy; above ~15 risks flicker.
- Higher rates can cause flicker on some terminals even with 2026 — the Copilot
  banner used **75 ms (~13 fps)** and explicitly warns higher "can cause flicker."
- For accuracy, subtract render time from the sleep (use a monotonic clock) so
  timing doesn't drift. For short loops this rarely matters.
- **Keep intros short** (the Copilot banner was 3 seconds total) and
  **non-blocking** — never delay the user's first interaction behind an
  animation.

## The animation data model

The format consumed by `preview.py` (see `assets/examples/dot.anim.json`):

```json
{
  "fps": 12,
  "loop": true,
  "frames": [ <frame>, <frame>, ... ]
}
```

Each `<frame>` is either a bare grid object (sprite or rgb) using the global fps,
or `{"grid": <grid>, "duration_ms": 150}` to override one frame's timing. All
frames should share the same cell dimensions (the player assumes a stable height
for in-place repaint).

**The two tools take different inputs:** `halfblock_render.py` renders a single
bare grid and errors on the `{fps,loop,frames}` envelope. To shape-check an
animation, run `preview.py --ascii` (prints every frame's no-color silhouette)
or `preview.py` to play it — the envelope is `preview.py`'s job, not the
renderer's.

The production-grade model (from the Copilot banner) adds **semantic color roles**
per frame so themes can recolor without touching geometry:

```
AnimationFrame { title, content (text grid), duration, colors: {"row,col": role} }
Animation { metadata, frames[] }
Theme: role -> ANSI color, with light/dark variants
```

ASCII Motion's model goes further (layers, keyframed transforms with easing,
onion-skinning) — see `ascii-motion-mcp.md`. For most embeddable assets, the
simple frame-array model is enough.

## Sprite sheets

For many small frames (walk cycles, idle loops), store a **sprite sheet**: one
grid containing all frames in a row/column, plus metadata (frame width, count,
order, durations). At runtime, slice the sub-grid for the current frame. This
keeps a single asset file and makes adding frames cheap. The slice is just a
window into the grid's columns/rows before rendering.

## Avoiding flicker (beyond 2026)

- **One write per frame.** Batch the whole frame into a single `stdout.write`
  (build a buffer, write once). Many small writes flicker.
- **Redraw only changed cells.** Diff against the previous frame and emit only
  the cells that changed (with cursor moves to each). This is what Ratatui does
  internally and what high-frame-rate terminal apps rely on. For small art the
  full-frame-with-2026 approach is simpler and usually sufficient.
- **Separate static and animated regions.** Don't repaint the parts that don't
  move.
- **Hide the cursor** during playback so the caret doesn't strobe.

## Players and libraries

- **`scripts/preview.py`** (this skill) — frame/animation player with 2026,
  in-place repaint, non-tty fallback.
- **chafa** — plays animated GIFs directly (`chafa anim.gif`), symbol mode.
- **Ratatui** — drive frames from your app loop; combine with `tachyonfx` for
  shader-like transitions. See `ratatui.md`.
- **ASCII Motion** — authors animations and exports GIF/MP4/WebM and framework
  components; `ascii-motion-mcp.md`.
- **Spinners** are the simplest animation (a cycling glyph). Fine for loaders;
  not what this skill is mainly about, but the same loop applies.

## Accessibility

Make animation **opt-in**, keep it short, and **skip it under screen-reader
mode** (the Copilot banner is skipped with `--screen-reader`). Provide a static
fallback frame. Respect reduced-motion preferences where you can detect them.
