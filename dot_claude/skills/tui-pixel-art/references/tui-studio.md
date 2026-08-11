# TUIStudio — `.tui` Layout Format & Exporters

`github.com/jalonsogo/tui-studio` (hosted at **tui.studio**) is a browser-based
TUI **layout/widget composition** tool. It is **secondary** to this skill: it
builds component layouts (panels, boxes, text widgets), **not** half-block pixel
art. Relevant only when you need to place a crafted asset inside a larger TUI
layout and want a starting scaffold in a real framework.

## What it is / isn't

- **Is:** a visual builder for terminal UI layouts that exports to several TUI
  frameworks. Browser-only (Vite/React app).
- **Isn't:** a pixel-art editor, and it has **no MCP server, no API, no CLI**. You
  cannot drive it programmatically — it's file-based only. (Contrast ASCII Motion,
  which *does* have an MCP server — `ascii-motion-mcp.md`.)

## The `.tui` format

A JSON document describing a widget tree:

```json
{
  "version": "1.0",
  "meta": { "name": "My Layout", "theme": "dark", "savedAt": "..." },
  "tree": { /* nested widget nodes: type, props, children, layout */ }
}
```

It's a layout description (component types + props + nesting), not a pixel grid.
Don't expect to store half-block art in it; store art in this skill's grid format
and *embed* the rendered asset into a layout the framework draws.

## Exporters

TUIStudio exports the layout to: **Ink** (React/Node), **BubbleTea** (Go),
**Blessed** (Node), **Textual** (Python), **OpenTUI**, and **tview** (Go). Note it
does **not** export Ratatui. If you're on Ratatui, treat TUIStudio output as
reference structure to translate, and render your half-block asset with the
widget in `ratatui.md`.

> Ink note: TUIStudio's Ink export is React-in-the-terminal. This skill doesn't
> center Ink — prefer BubbleTea/OpenTUI/Textual exports, or translate to Ratatui.

## When to use it

Only when composing a **larger TUI layout** around your art and you want a quick
visual scaffold in BubbleTea/Textual/OpenTUI. For the art itself — mascots,
logos, sprites, animation — it contributes nothing; use the rest of this skill.
