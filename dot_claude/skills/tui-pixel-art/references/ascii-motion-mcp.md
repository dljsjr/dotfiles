# ASCII Motion MCP — Authoring & Export

ASCII Motion (ascii-motion.app) is a web editor for ASCII / half-block art and
animation. It ships a **separate MCP server** (`ascii-motion-mcp`, community-
built by the app's author — **not** an Anthropic product) exposing **70+ tools**
across 13 categories. When it's connected, you can author frames programmatically
and export directly to TUI-friendly formats — which makes it a strong companion
to this skill for interactive authoring.

## Setup (for the user)

```bash
npm install -g ascii-motion-mcp
```

Claude Desktop config (`claude_desktop_config.json`):

```json
{
  "mcpServers": {
    "ascii-motion": {
      "command": "ascii-motion-mcp",
      "args": ["--live", "--project-dir", "/Users/you/ascii-projects"]
    }
  }
}
```

`--live` enables real-time sync with the browser editor over WebSocket (port
**9876**; `--port` to change). The handshake: ask for the auth token
(`get_auth_token`), then in ascii-motion.app open the ☰ menu → **MCP Connection**
→ paste the token → Connect. Edits then appear live in the browser. Export tools
write files without the browser; the visual feedback needs it.

## The mental model you must bridge

ASCII Motion's native cell is **character + foreground + background** — it is a
*character* canvas, not a *pixel* canvas. So to produce **half-block pixel art**
specifically, you drive it one of two ways:

1. **Half-block cells directly:** `set_cell`/`set_cells_batch` with `char` = `▀`
   (or `▄`) and per-cell `color` (fg) + `bgColor` (bg). This is the pixel-art
   path — each cell is two stacked pixels, exactly as in this skill.
2. **Import + block palette:** `import_image` with `colorMode: "both"` and the
   `block-characters` palette (`░▒▓█`), then refine.

Then **export to your runtime**. Don't hand-place pixels char-by-char when you
can import and adjust.

## Tool surface (70+ tools, by category)

**Canvas (8):** `get_canvas_summary`, `resize_canvas` (width/height/anchor),
`clear_canvas`, `clear_cells`, `get_cell`, **`set_cell`** (x, y, char, color,
bgColor, frameIndex), **`set_cells_batch`** (array, max **10,000**/batch),
`inspect_cells` (region).

**Drawing (5):** `draw_line` (Bresenham), `draw_rectangle` (filled?),
`draw_circle`, `draw_ellipse`, `type_text` (x, y, text, font, color).

**Selection (6):** `get_selection`, `select_rectangle`, `select_by_color`,
`apply_to_selection`, `recolor_selection`, `clear_selection`.

**Fill / region (2):** `fill_region` (flood fill; char, colors, contiguous,
match criteria), `flip_region` (horizontal/vertical).

**Frames (8):** `get_frame_info`, **`add_frame`** (atIndex, copyFrom),
`delete_frame`, **`duplicate_frame`**, `go_to_frame`, **`set_frame_duration`**
(ms), `copy_region_between_frames`, **`interpolate_frames`** (startFrame,
endFrame, count — tweening).

**Effects (6):** `apply_effect` (invert, grayscale, sepia, pixelate, blur,
sharpen, hueShift, scanlines, glitch, noise, vignette, chromatic),
`get_color_stats`, **`create_gradient`** (startColor, endColor,
horizontal/vertical/radial), `color_cycle_animation`, **`apply_dithering`**
(`floyd-steinberg` | `ordered` | `random`, colorCount),
`adjust_brightness_contrast`.

**Palettes (9):** `list_character_palettes` (`minimal-ascii`, `standard-ascii`,
`block-characters` ░▒▓█, `retro-computing`, `box-drawing-light/double`),
`get_character_palette`, `list_color_palettes` (**`ansi-16`**, `monochrome-green`,
`grayscale`, `rainbow`, `retro-8bit`), `get_color_palette`,
`get`/`set_foreground_color`, `get`/`set_background_color`,
`suggest_palette_for_style`.

**Import (4):** **`import_image`** (filePath, targetWidth/Height, charset,
`colorMode`: none/foreground/background/**both**, dithering: none/floyd-
steinberg/ordered), `import_json`, `import_ansi` (.ans), `import_ascii_text`.

**Export (12):** **`export_ansi`** (terminal escape codes), `export_html`,
`export_png`, `export_svg`, `export_json`, **`export_gif`** (fps, loop),
`export_mp4`, `export_webm`, **`export_bubbletea`** (Go TUI; packageName),
`export_ink` (Node CLI — see note), **`export_opentui`**, `export_react`.

**Project (6):** `create_project` (name, width, height), `load_project`,
`save_project`, `get_project_info`, `list_project_files`, `get_auth_token`.

**Undo/redo (3):** `get_undo_status`, `undo`, `redo`.
**Connection (2):** `get_connection_status`, `get_auth_token`.
**Clipboard (3):** `copy_to_clipboard`, `paste_from_clipboard`,
`get_clipboard_contents`.

## Recipes

**Author a small static asset, export for embedding**
1. `create_project` (or `resize_canvas`) to your cell footprint.
2. Place pixels: `set_cells_batch` with `char:"▀"`, per-cell `color`/`bgColor` —
   or `import_image` then refine.
3. `export_ansi` for a runtime-agnostic string, **or** `export_bubbletea` /
   `export_opentui` for a framework component.
4. For Ratatui: `export_ansi` or `export_json`, then load via the patterns in
   `ratatui.md` (the JSON carries char + fg + bg per cell).

**Convert a logo**
`import_image` (targetWidth ~32–48, `colorMode:"both"`, optional
`dithering:"floyd-steinberg"`) → `apply_dithering`/`adjust_brightness_contrast`
to taste → export.

**Animate**
`add_frame`/`duplicate_frame` per frame → edit each → `set_frame_duration` (ms)
or `interpolate_frames` to tween between keyframes → `export_gif` (preview) and
`export_bubbletea`/`export_opentui` (embed). `color_cycle_animation` for cheap
palette-cycling motion.

## Getting ASCII Motion output into Ratatui

ASCII Motion exports **Ink, BubbleTea, OpenTUI, React** — not Ratatui directly.
Bridge via:
- **`export_ansi`** → a ready string you can `print!` or stuff into a Ratatui
  `Text`/`Paragraph` (it already contains the SGR codes), or
- **`export_json`** → parse the per-cell char/fg/bg and rebuild a
  `HalfblockImage` (see `ratatui.md`). This is the cleaner path — you keep the
  grid and re-theme/downscale in Rust.

> Ink note: `export_ink` produces React-for-the-terminal components. This skill
> does not center Ink — prefer `export_ansi`/`export_json` → Ratatui, or
> `export_bubbletea`/`export_opentui`. The Ink export exists; you need not use it.

## Caveats

- Third-party/community tool; live visual feedback requires the browser editor
  open and the WebSocket connected.
- It's a *character* canvas — be deliberate about driving it for half-block pixel
  art (char `▀`/`▄` + fg/bg), not generic ASCII, when pixel fidelity is the goal.
- Use `ansi-16` palette + semantic intent if the asset must be themeable.
