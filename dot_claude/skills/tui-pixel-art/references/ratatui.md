# Rendering Half-Block Art in Ratatui

Ratatui is the recommended framework target (it's also what the best reference
implementations — pixtuoid and rebels-in-the-sky — actually use). The approach:
write half-block cells directly into Ratatui's `Buffer`, one cell per pair of
pixel rows, setting `symbol` + `fg` + `bg` per cell. Ratatui's own diffing then
handles minimal redraws and flicker — you don't manage the cursor or escape
sequences yourself.

> The Rust below targets the `ratatui` 0.30 Buffer/Cell API and compiles clean
> against it (`cargo build`, only dead-code warnings). It is reference code —
> compile-check it against your pinned `ratatui` version. Where the API has
> shifted across versions, the alternative is noted inline.

## Contents
- Cargo deps
- The core widget: grid → Buffer
- Loading the skill's JSON formats
- Color depth
- Animation in Ratatui
- How the reference implementations do it
- When to use `ratatui-image` instead

## Cargo deps

```toml
[dependencies]
ratatui = "0.30"
serde = { version = "1", features = ["derive"] }
serde_json = "1"
```

## The core widget: grid → Buffer

```rust
use ratatui::{buffer::Buffer, layout::Rect, style::Color, widgets::Widget};

pub type Px = Option<(u8, u8, u8)>; // None = transparent

/// A small half-block image: a pixel grid that renders 2 pixel-rows per cell-row.
pub struct HalfblockImage {
    pub width: u16,        // pixels wide
    pub height: u16,       // pixels tall
    pub pixels: Vec<Px>,   // row-major, len == width * height
}

impl HalfblockImage {
    #[inline]
    fn get(&self, x: u16, y: u16) -> Px {
        if x < self.width && y < self.height {
            self.pixels[y as usize * self.width as usize + x as usize]
        } else {
            None
        }
    }

    /// Cell footprint: width cells wide, ceil(height/2) cells tall.
    pub fn cell_size(&self) -> (u16, u16) {
        (self.width, self.height.div_ceil(2))
    }
}

impl Widget for &HalfblockImage {
    fn render(self, area: Rect, buf: &mut Buffer) {
        const UPPER: &str = "\u{2580}"; // ▀ fg=top, bg=bottom
        const LOWER: &str = "\u{2584}"; // ▄ fg=bottom (top transparent)

        let cell_rows = self.height.div_ceil(2);
        for cy in 0..cell_rows {
            let (top_y, bot_y) = (cy * 2, cy * 2 + 1);
            for x in 0..self.width {
                let sx = area.x + x;
                let sy = area.y + cy;
                // Clip to the widget's area.
                if sx >= area.right() || sy >= area.bottom() {
                    continue;
                }
                let top = self.get(x, top_y);
                let bot = self.get(x, bot_y);

                // ratatui 0.30: index the buffer for &mut Cell. NOTE this
                // panics if (sx, sy) is outside the backing buffer; the clip
                // above only bounds against `area`, so use the non-panicking
                // `buf.cell_mut((sx, sy))` (-> Option<&mut Cell>) if `area` can
                // exceed the terminal. (`buf.get_mut(sx, sy)` still exists but
                // is deprecated.)
                let cell = &mut buf[(sx, sy)];
                match (top, bot) {
                    (None, None) => {
                        cell.set_symbol(" ");
                    }
                    (Some(t), None) => {
                        cell.set_symbol(UPPER);
                        cell.set_fg(Color::Rgb(t.0, t.1, t.2));
                    }
                    (None, Some(b)) => {
                        cell.set_symbol(LOWER);
                        cell.set_fg(Color::Rgb(b.0, b.1, b.2));
                    }
                    (Some(t), Some(b)) => {
                        cell.set_symbol(UPPER);
                        cell.set_fg(Color::Rgb(t.0, t.1, t.2));
                        cell.set_bg(Color::Rgb(b.0, b.1, b.2));
                    }
                }
            }
        }
    }
}
```

Render it like any widget:

```rust
frame.render_widget(&image, some_rect);
```

## Loading the skill's JSON formats

The same sprite/rgb JSON the Python scripts use, via serde:

```rust
use std::collections::HashMap;

#[derive(serde::Deserialize)]
#[serde(untagged)]
enum GridFile {
    Sprite { palette: HashMap<String, Option<[u8; 3]>>, rows: Vec<String> },
    Rgb { width: u16, height: u16, pixels: Vec<Vec<Option<[u8; 3]>>> },
}

impl GridFile {
    fn into_image(self) -> HalfblockImage {
        match self {
            GridFile::Sprite { palette, rows } => {
                let pal: HashMap<char, Px> = palette
                    .into_iter()
                    .map(|(k, v)| (k.chars().next().unwrap(),
                                   v.map(|c| (c[0], c[1], c[2]))))
                    .collect();
                let height = rows.len() as u16;
                let width = rows.first().map_or(0, |r| r.chars().count()) as u16;
                let pixels = rows
                    .iter()
                    .flat_map(|r| r.chars().map(|ch| pal[&ch]))
                    .collect();
                HalfblockImage { width, height, pixels }
            }
            GridFile::Rgb { width, height, pixels } => {
                let flat = pixels
                    .into_iter()
                    .flatten()
                    .map(|p| p.map(|c| (c[0], c[1], c[2])))
                    .collect();
                HalfblockImage { width, height, pixels: flat }
            }
        }
    }
}

// let image = serde_json::from_str::<GridFile>(json)?.into_image();
```

This lets you author with the Python tooling (and ASCII Motion / chafa) and load
the exact same asset files in Rust.

## Color depth

`Color::Rgb(r,g,b)` is truecolor. To downgrade for portability:

- **256-color:** `Color::Indexed(n)` where `n` is the nearest xterm-256 index.
  Port the `_rgb_to_256` logic from `scripts/halfblock_render.py` (6×6×6 cube +
  grayscale ramp).
- **16-color:** `Color::Indexed(0..16)` or the named `Color` variants. Port
  `_rgb_to_16`. Remember 16-color can't represent orange/brown — design within
  its gamut if you target it.

Ratatui will emit whatever the terminal/backend supports; choosing `Indexed`
keeps you portable. Keep the depth a property of your theme, not the asset.

## Animation in Ratatui

Don't hand-roll a frame loop with cursor moves — let Ratatui do it:

1. Hold the current frame index in your app state.
2. On each tick (e.g. a 12 fps timer event), advance the frame and swap the
   widget's `pixels` (or slice a sprite sheet).
3. Call `terminal.draw(|f| f.render_widget(&image, rect))`.

Ratatui diffs against the previous buffer and writes only changed cells; recent
versions emit synchronized-output sequences via the backend, so you get
flicker-free animation without managing DECSET 2026 yourself. For richer
transitions (fades, dissolves), the `tachyonfx` crate composes shader-like
effects over Ratatui buffers.

## How the reference implementations do it

- **pixtuoid** (Rust + Ratatui): pipeline is `pose → pixel_painter → RgbBuffer →
  half-block → ratatui` at ~30 fps. Sprite packs + a half-block renderer in a
  real TUI — the closest analog to this skill's approach.
- **rebels-in-the-sky** (Rust + Ratatui): decodes GIF/PNG sprite assets to RGBA
  and writes per-cell fg/bg half-block cells into the buffer — a **custom
  half-block renderer**, notably *not* using `ratatui-image` (its deps are
  `gif` + `image` + `ratatui`). Confirms the grid→Buffer pattern at scale; it
  recommends a 160×48 terminal and even runs over SSH.

See `reference-implementations.md` for more.

## When to use `ratatui-image` instead

`ratatui-image` is a ready-made widget that auto-detects Sixel/Kitty/iTerm2 and
**falls back to half-blocks** (4:8 pixel ratio) in plain terminals. It's great
when you want to display *arbitrary images* and opportunistically use image
protocols where available. But this skill is about **deliberate small assets in
pure Unicode** — for that, the custom widget above gives you exact control over
glyphs, transparency, and palette, which is what the production sprite engines
chose. Use `ratatui-image` for "show this image"; use the widget here for
"render my crafted sprite."
