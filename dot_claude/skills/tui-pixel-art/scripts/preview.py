#!/usr/bin/env python3
"""
preview.py - play a single frame or a frame-based animation in the terminal.

Renders with halfblock_render and handles the things that make terminal
animation actually watchable:

  * SYNCHRONIZED OUTPUT (DECSET 2026). Each repaint is wrapped in
    ESC[?2026h ... ESC[?2026l so the terminal swaps the whole frame atomically
    instead of showing you a half-drawn frame. This is THE fix for flicker and
    cursor-tearing; without it, fast repaints shimmer. Terminals that don't
    understand 2026 simply ignore it, so it is always safe to send.

  * IN-PLACE REPAINT. After the first frame we move the cursor up N lines and
    redraw, rather than clearing the whole screen. Less work, less flicker, and
    the animation stays inline in the scrollback instead of taking over.

  * CURSOR HIDDEN during playback (ESC[?25l) and restored on exit, even on
    Ctrl-C, so you never see the caret strobing through the art.

  * NON-TTY FALLBACK. If stdout is not a terminal (piped, logged), it prints
    each frame once, stacked, with no escape sequences.

ANIMATION JSON FORMAT
---------------------
    {
      "fps": 12,                  // default frame rate (ms/frame = 1000/fps)
      "loop": true,               // loop forever when interactive
      "frames": [ <frame>, ... ]  // 2+ frames
    }

Each <frame> is either:
  * a bare grid object (sprite {"palette","rows"} or rgb {"pixels"}), using the
    global fps for its duration, OR
  * {"grid": <grid object>, "duration_ms": 150} to override one frame's timing.

All frames should share the same cell dimensions (height especially); the
player validates this and warns if they differ, since in-place repaint assumes
a stable frame height.

USAGE
-----
    python3 preview.py mascot.json                 # show one still frame
    python3 preview.py walk.anim.json              # loop an animation (Ctrl-C)
    python3 preview.py walk.anim.json --once        # play through once, then stop
    python3 preview.py walk.anim.json --ascii       # silhouette of every frame, no color
    python3 preview.py walk.anim.json --color 256   # downgrade color depth
    python3 preview.py walk.anim.json --no-sync      # disable 2026 (to compare)
    python3 preview.py walk.anim.json --dump 6       # write raw control stream
                                                     #   for 6 frames and exit
                                                     #   (for inspection/testing)
"""

from __future__ import annotations

import argparse
import json
import sys
import time
from typing import List, Optional, Sequence, Tuple

import halfblock_render as hb

HIDE_CURSOR = "\x1b[?25l"
SHOW_CURSOR = "\x1b[?25h"
SYNC_BEGIN = "\x1b[?2026h"
SYNC_END = "\x1b[?2026l"
CLEAR_LINE = "\x1b[2K"


class Frame:
    __slots__ = ("lines", "duration")

    def __init__(self, lines: List[str], duration: float):
        self.lines = lines
        self.duration = duration


def _load_frames(path: str, color: str) -> Tuple[List[Frame], bool]:
    """Return (frames, loop). A single still grid becomes one frame."""
    with open(path, "r", encoding="utf-8") as fh:
        obj = json.load(fh)

    if "frames" in obj:
        fps = obj.get("fps", 12)
        default_ms = 1000.0 / fps if fps else 100.0
        loop = bool(obj.get("loop", True))
        frames: List[Frame] = []
        for item in obj["frames"]:
            if isinstance(item, dict) and "grid" in item:
                grid = hb.parse_grid(item["grid"])
                ms = float(item.get("duration_ms", default_ms))
            else:
                grid = hb.parse_grid(item)
                ms = default_ms
            frames.append(Frame(hb.render_lines(grid, color=color), ms / 1000.0))
    else:
        grid = hb.parse_grid(obj)
        frames = [Frame(hb.render_lines(grid, color=color), 0.0)]
        loop = False

    heights = {len(f.lines) for f in frames}
    if len(heights) > 1:
        sys.stderr.write(
            f"[warning] frames have differing cell-heights {sorted(heights)}; "
            f"in-place repaint works best with a uniform height\n"
        )
    return frames, loop


def _emit(text: str) -> None:
    sys.stdout.write(text)
    sys.stdout.flush()


def _paint(frame: Frame, *, first: bool, height: int, sync: bool) -> None:
    """Repaint one frame in place."""
    buf: List[str] = []
    if sync:
        buf.append(SYNC_BEGIN)
    if not first:
        buf.append(f"\x1b[{height}A")  # cursor up to top of previous frame
    buf.append("\r")
    for line in frame.lines:
        buf.append(CLEAR_LINE)
        buf.append(line)
        # newline after every line except keep cursor manageable: we always
        # print height lines so the cursor ends below the frame predictably.
        buf.append("\n")
    # If this frame is shorter than the tallest seen, clear the leftover lines.
    for _ in range(height - len(frame.lines)):
        buf.append(CLEAR_LINE + "\n")
    if sync:
        buf.append(SYNC_END)
    _emit("".join(buf))


def play(
    frames: List[Frame],
    loop: bool,
    *,
    sync: bool = True,
    once: bool = False,
) -> int:
    height = max(len(f.lines) for f in frames)
    interactive = sys.stdout.isatty()

    if not interactive:
        # Non-tty: dump each frame once, stacked, no escapes-as-animation.
        for f in frames:
            _emit("\n".join(f.lines) + "\n")
        return 0

    _emit(HIDE_CURSOR)
    first = True
    try:
        while True:
            for f in frames:
                _paint(f, first=first, height=height, sync=sync)
                first = False
                if f.duration > 0:
                    time.sleep(f.duration)
            if once or not loop:
                break
    except KeyboardInterrupt:
        pass
    finally:
        _emit(SHOW_CURSOR)
    return 0


def dump(frames: List[Frame], n: int, *, sync: bool = True) -> int:
    """Write the raw control stream for up to n frame-repaints to stdout
    (regardless of tty), for inspection or automated testing."""
    height = max(len(f.lines) for f in frames)
    first = True
    count = 0
    seq = frames + frames  # allow wrap for short sets
    for f in seq:
        if count >= n:
            break
        _paint(f, first=first, height=height, sync=sync)
        first = False
        count += 1
    return 0


def dump_ascii(path: str) -> int:
    """Print each frame's no-color brightness silhouette, stacked, then exit.

    The shape-check analog of `halfblock_render.py --ascii`, but for the
    animation envelope (which halfblock_render can't read): use it to eyeball
    every frame's silhouette in a plain log, with no color and no animation.
    """
    with open(path, "r", encoding="utf-8") as fh:
        obj = json.load(fh)
    frames = obj["frames"] if "frames" in obj else [obj]
    for i, item in enumerate(frames):
        grid_obj = item["grid"] if isinstance(item, dict) and "grid" in item else item
        grid = hb.parse_grid(grid_obj)
        if len(frames) > 1:
            sys.stdout.write(f"--- frame {i} ---\n")
        sys.stdout.write(hb.render_ascii(grid) + "\n")
    return 0


def main(argv: Optional[Sequence[str]] = None) -> int:
    ap = argparse.ArgumentParser(description="Play half-block frames/animations.")
    ap.add_argument("path", help="grid JSON (still) or animation JSON")
    ap.add_argument("--color", choices=["truecolor", "256", "16"],
                    default="truecolor")
    ap.add_argument("--once", action="store_true",
                    help="play through frames once, then stop")
    ap.add_argument("--no-sync", action="store_true",
                    help="disable DECSET 2026 synchronized output (to compare)")
    ap.add_argument("--dump", type=int, metavar="N", default=0,
                    help="write the raw control stream for N repaints and exit")
    ap.add_argument("--ascii", action="store_true",
                    help="print each frame's no-color silhouette (shape check) and exit")
    args = ap.parse_args(argv)

    try:
        if args.ascii:
            return dump_ascii(args.path)
        frames, loop = _load_frames(args.path, args.color)
    except (ValueError, KeyError, OSError, json.JSONDecodeError) as e:
        sys.stderr.write(f"error: {e}\n")
        return 2
    sync = not args.no_sync
    if args.dump:
        return dump(frames, args.dump, sync=sync)
    return play(frames, loop, sync=sync, once=args.once)


if __name__ == "__main__":
    raise SystemExit(main())
