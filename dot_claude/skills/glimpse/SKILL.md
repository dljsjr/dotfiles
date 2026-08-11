---
name: glimpse
description: Show native UI from a Node script — dialogs, forms, selection lists, charts, markdown viewers, progress windows, floating widgets, cursor companions. Use whenever you need to display HTML to the user, collect structured input (more than yes/no), preview generated content visually, confirm a destructive action with a real dialog, or surface a persistent indicator while work happens in the background. Triggers: "glimpse", "show me a UI", "open a window", "render this", "preview", "confirm dialog", "form input", "let me pick", "draw a chart", "floating widget".
---

# Glimpse — Native Micro-UI

Glimpse opens a native window with a webview in under 50ms. You write HTML, the user sees it instantly. Bidirectional communication via `window.glimpse.send()` (webview → Node) and `win.send(js)` (Node → webview). Works on macOS (WKWebView), Linux (WebKitGTK), and Windows (WebView2).

**When Glimpse is the right tool:**
- You need user input beyond yes/no (forms, selections, free text)
- You want to show something visual (charts, markdown, images, diffs)
- You want to confirm a destructive action with a real dialog
- You want a floating indicator, toast notification, or cursor companion
- You need the user to interact with rich content

**When it's not:**
- A simple yes/no — `AskUserQuestion` is faster and cheaper
- Anything that needs to persist beyond this session — Glimpse windows die with the Node process

## Running Glimpse from Claude Code

Glimpse is a Node ESM script. There are two invocation shapes.

### One-shot prompt (modal dialog, blocks until user responds)

Write the script to a temp file with `Write`, then run it via `Bash`:

```bash
node /tmp/my-glimpse-prompt.mjs
```

The script's stdout is the user's response (or `null` if they closed the window). Capture it normally from `Bash`'s output. For trivially short scripts you can use `node --input-type=module -e '...'` instead of writing a file, but Write + Bash is easier to debug.

### Persistent window (toast, progress, indicator, kanban, anything long-lived)

Run the script with `Bash` and **`run_in_background: true`** so the window stays open without blocking your agent loop:

```
Bash(command: "node /tmp/my-glimpse-window.mjs", run_in_background: true)
```

Then:
- **Inspect output**: `Read` the `.output` file path returned by `Bash` (preferred), or `TaskOutput` with `block: false` for a non-blocking status check. Useful when the script logs progress or surfaces messages from the webview via `win.on('message', ...)` and prints them.
- **Push updates into the webview**: do that from inside the script itself (Node side), not from Claude Code. Plan the script to read stdin, watch a file, or poll something — Claude Code can't reach into the running window directly.
- **Close the window**: `TaskStop` against the task id, or have the script time out / close on its own (`win.close()` or `autoClose: true`).

Background process stdout is not auto-injected into the agent loop — use `Read` on the `.output` path when you want to see it.

## Import path

Glimpse lives at `/Users/doug.stephen/git/glimpse/src/glimpse.mjs` (Doug's local checkout). Always import by absolute path — the bare `'glimpseui'` specifier fails when scripts run from `/tmp` or anywhere without `node_modules`:

```js
import { open, prompt } from '/Users/doug.stephen/git/glimpse/src/glimpse.mjs';
```

(On Windows, ESM absolute imports need a `file:///C:/...` URL. macOS/Linux take the path directly.)

---

## Quick Reference

### One-Shot Dialog (prompt)

```js
import { prompt } from '/Users/doug.stephen/git/glimpse/src/glimpse.mjs';

const answer = await prompt(html, {
  width: 400, height: 300,    // window size
  title: 'My Dialog',         // title bar text
  frameless: true,            // no title bar
  transparent: true,          // see-through background
});
// answer = data from window.glimpse.send(), or null if user closed the window
console.log(JSON.stringify(answer));
```

### Persistent Window (open)

```js
import { open } from '/Users/doug.stephen/git/glimpse/src/glimpse.mjs';

const win = open(html, options);
win.on('ready', (info) => {});       // HTML loaded — info has screen, appearance, cursor
win.on('message', data => {});       // user interaction
win.on('info', info => {});          // fresh system info (after getInfo())
win.on('closed', () => {});          // window gone
win.send('document.title = "Hi"');   // eval JS in webview
win.setHTML('<h1>New content</h1>'); // replace HTML
win.info;                            // last-known system info
win.getInfo();                       // request fresh info
win.close();                         // close window
```

### All Options

```js
{
  width, height,          // pixels (default: 800×600)
  title,                  // window title (default: "Glimpse")
  frameless: true,        // no title bar, draggable by background
  floating: true,         // always on top
  transparent: true,      // transparent window background
  clickThrough: true,     // mouse passes through window
  followCursor: true,     // window follows mouse cursor
  followMode: 'spring',   // 'snap' (instant, default) or 'spring' (elastic)
  cursorAnchor: 'top-right', // snap point: top-left, top-right, right, bottom-right, bottom-left, left
  cursorOffset: {x, y},   // offset from cursor (default: 20, -20)
  openLinks: true,        // open clicked http/https links in default browser
  openLinksApp: '/Applications/Google Chrome.app', // optional app bundle path
  autoClose: true,        // close after first message
  noDock: true,           // no dock icon or app switcher entry (macOS)
  x, y,                   // exact screen position
  timeout,                // for prompt() only — ms before rejecting
}
```

### System Info (available on `ready`)

```js
win.on('ready', (info) => {
  info.screen.width            // 2560 (full resolution)
  info.screen.height           // 1440
  info.screen.scaleFactor      // 2 (Retina)
  info.screen.visibleWidth     // 2560 (excluding dock)
  info.screen.visibleHeight    // 1367 (excluding menu bar)

  info.appearance.darkMode          // true
  info.appearance.accentColor       // "#007AFF"
  info.appearance.reduceMotion      // false
  info.appearance.increaseContrast  // false

  info.cursor.x   // 500
  info.cursor.y   // 800

  info.screens    // [{ x, y, width, height, scaleFactor, ... }, ...] for every monitor
});

// Access anytime after ready:
win.info.screen.width
win.info.appearance.darkMode
```

### In-Page JavaScript Bridge

```js
window.glimpse.send(data)  // send data to Node (any JSON-serializable value)
window.glimpse.close()     // close the window from JS
```

---

## Patterns

### 1. Confirm Dialog

Ask yes/no, get the answer, move on. Use this for destructive confirmations where `AskUserQuestion` feels too plain.

```js
const answer = await prompt(`
<body style="font-family: system-ui; padding: 24px; background: white;">
  <h2 style="margin-top: 0;">Delete 47 files?</h2>
  <p style="color: #666;">This cannot be undone.</p>
  <div style="display: flex; gap: 8px; justify-content: flex-end;">
    <button onclick="window.glimpse.send({ok: false})"
      style="padding: 10px 20px; font-size: 14px; border: 1px solid #ddd; border-radius: 8px; background: white; cursor: pointer;">
      Cancel
    </button>
    <button onclick="window.glimpse.send({ok: true})" autofocus
      style="padding: 10px 20px; font-size: 14px; border: none; border-radius: 8px; background: #e53e3e; color: white; cursor: pointer;">
      Delete
    </button>
  </div>
  <script>
    document.addEventListener('keydown', e => {
      if (e.key === 'Escape') window.glimpse.send({ok: false});
      if (e.key === 'Enter') window.glimpse.send({ok: true});
    });
  </script>
</body>
`, { width: 340, height: 180, title: 'Confirm' });

if (answer?.ok) { /* proceed with deletion */ }
```

### 2. Text Input Form

Collect structured input. Enter submits, Escape cancels.

```js
const result = await prompt(`
<body style="font-family: system-ui; padding: 24px; background: white;">
  <style>
    input, select { padding: 8px 12px; font-size: 14px; border: 1px solid #ddd; border-radius: 6px; width: 100%; margin-bottom: 12px; }
    input:focus, select:focus { outline: none; border-color: #4299e1; box-shadow: 0 0 0 3px rgba(66,153,225,0.15); }
    button { padding: 10px 20px; border: none; border-radius: 8px; cursor: pointer; font-size: 14px; }
  </style>
  <h3 style="margin-top: 0;">New Component</h3>
  <input id="name" placeholder="Component name" autofocus />
  <select id="type">
    <option value="page">Page</option>
    <option value="component">Component</option>
    <option value="layout">Layout</option>
  </select>
  <div style="display: flex; gap: 8px; justify-content: flex-end;">
    <button onclick="window.glimpse.send(null)" style="background: #eee;">Cancel</button>
    <button onclick="submit()" style="background: #4299e1; color: white;">Create</button>
  </div>
  <script>
    function submit() {
      window.glimpse.send({
        name: document.getElementById('name').value,
        type: document.getElementById('type').value,
      });
    }
    document.getElementById('name').addEventListener('keydown', e => {
      if (e.key === 'Enter') submit();
      if (e.key === 'Escape') window.glimpse.send(null);
    });
  </script>
</body>
`, { width: 380, height: 260, title: 'Create' });

if (result) console.log(`Creating ${result.type}: ${result.name}`);
```

### 3. Selection List

Pick from a list of options. Click or use arrow keys + Enter.

```js
function pickFromList(title, items) {
  const itemsHTML = items.map((item, i) =>
    `<div class="item${i === 0 ? ' selected' : ''}" data-index="${i}" onclick="pick(${i})">${item}</div>`
  ).join('');

  return prompt(`
  <body style="font-family: system-ui; margin: 0; background: white;">
    <style>
      .header { padding: 12px 16px; font-size: 13px; color: #888; border-bottom: 1px solid #eee; }
      .item { padding: 10px 16px; cursor: pointer; font-size: 14px; }
      .item:hover, .item.selected { background: #4299e1; color: white; }
    </style>
    <div class="header">${title}</div>
    <div id="list">${itemsHTML}</div>
    <script>
      const items = document.querySelectorAll('.item');
      let sel = 0;
      function pick(i) { window.glimpse.send({index: i, value: items[i].textContent}); }
      document.addEventListener('keydown', e => {
        if (e.key === 'ArrowDown') { items[sel].classList.remove('selected'); sel = (sel+1) % items.length; items[sel].classList.add('selected'); }
        if (e.key === 'ArrowUp') { items[sel].classList.remove('selected'); sel = (sel-1+items.length) % items.length; items[sel].classList.add('selected'); }
        if (e.key === 'Enter') pick(sel);
        if (e.key === 'Escape') window.glimpse.send(null);
        e.preventDefault();
      });
    </script>
  </body>
  `, { width: 300, height: 40 + items.length * 38, frameless: true });
}

const choice = await pickFromList('Pick a framework', ['React', 'Vue', 'Svelte', 'Solid', 'Angular']);
```

### 4. Markdown / Rich Content Viewer

Show formatted content. Useful for previewing generated docs, READMEs, or diffs.

```js
const markdown = `# Hello World\n\nThis is **bold** and this is \`code\`.`;

const win = open(`
<body style="font-family: system-ui; padding: 24px; background: white;">
  <div id="content"></div>
  <script src="https://cdn.jsdelivr.net/npm/marked/marked.min.js"></script>
  <script>
    document.getElementById('content').innerHTML = marked.parse(${JSON.stringify(markdown)});
  </script>
</body>
`, { width: 600, height: 400, title: 'Preview' });
```

### 5. Live Progress / Streaming Output

Push updates into the window as work progresses.

```js
const win = open(`
<body style="font-family: monospace; padding: 16px; background: #1a1a2e; color: #0f0; font-size: 13px;">
  <div id="log" style="white-space: pre-wrap;"></div>
  <script>
    window.appendLog = (text) => {
      document.getElementById('log').textContent += text + '\\n';
      window.scrollTo(0, document.body.scrollHeight);
    };
  </script>
</body>
`, { width: 500, height: 300, title: 'Build Progress' });

win.on('ready', () => {
  win.send(`appendLog('Starting build...')`);
  win.send(`appendLog('✓ Compiled 42 files')`);
  win.send(`appendLog('✓ Tests passed')`);
  win.send(`appendLog('✓ Done!')`);
});
```

### 6. Adaptive Dark/Light Mode

Use system info to style the UI to match the user's appearance.

```js
const win = open('', { width: 400, height: 200 });

win.on('ready', ({ appearance, screen }) => {
  const bg = appearance.darkMode ? '#1a1a2e' : '#ffffff';
  const fg = appearance.darkMode ? '#ffffff' : '#333333';
  const accent = appearance.accentColor;

  win.setHTML(`
    <body style="font-family: system-ui; padding: 24px; background: ${bg}; color: ${fg};">
      <h2 style="color: ${accent};">Adaptive UI</h2>
      <p>Dark mode: ${appearance.darkMode ? 'on' : 'off'}</p>
      <p>Screen: ${screen.width}×${screen.height} @${screen.scaleFactor}x</p>
      <button onclick="window.glimpse.close()"
        style="padding: 8px 16px; background: ${accent}; color: white; border: none; border-radius: 6px; cursor: pointer;">
        Close
      </button>
    </body>
  `);
});
```

### 7. Floating Notification

A brief, auto-dismissing toast. No interaction needed.

```js
function notify(message, durationMs = 3000) {
  const win = open(`
  <body style="margin: 0; background: transparent !important;">
    <div style="
      background: rgba(0,0,0,0.85); color: white; padding: 12px 20px;
      border-radius: 10px; font-family: system-ui; font-size: 14px;
      backdrop-filter: blur(20px); -webkit-backdrop-filter: blur(20px);
    ">${message}</div>
  </body>
  `, { width: 300, height: 60, frameless: true, transparent: true, floating: true, clickThrough: true });

  win.on('ready', () => setTimeout(() => win.close(), durationMs));
}

notify('✅ Deployed to production');
```

### 8. Cursor Companion

A visual element that follows the cursor. Great for agent status indicators.

```js
const win = open(`
<body style="background: transparent !important; margin: 0;">
  <svg width="50" height="50" style="filter: drop-shadow(0 0 6px rgba(0,255,200,0.5));">
    <circle cx="25" cy="25" r="18" fill="none" stroke="cyan" stroke-width="2" stroke-dasharray="20 60">
      <animateTransform attributeName="transform" type="rotate"
        from="0 25 25" to="360 25 25" dur="0.8s" repeatCount="indefinite"/>
    </circle>
  </svg>
</body>
`, {
  width: 50, height: 50,
  transparent: true, frameless: true,
  followCursor: true, clickThrough: true,
  cursorOffset: { x: 20, y: -20 },
});

setTimeout(() => win.close(), 10_000);
```

### 9. Agent Thinking Indicator

Show a pulsing indicator while the agent is processing. Run this as a background `Bash` so the indicator persists; close it with `KillShell` when the long-running work is done.

```js
const win = open(`
<body style="background: transparent !important; margin: 0;">
  <div style="
    display: flex; align-items: center; gap: 8px; padding: 8px 16px;
    background: rgba(0,0,0,0.8); border-radius: 20px;
    backdrop-filter: blur(10px); font-family: system-ui; color: white; font-size: 13px;
  ">
    <div style="width: 8px; height: 8px; border-radius: 50%; background: #ffd700; animation: pulse 1s ease-in-out infinite;"></div>
    Thinking...
  </div>
  <style>@keyframes pulse { 0%,100% { opacity: 0.4; } 50% { opacity: 1; } }</style>
</body>
`, { width: 140, height: 40, frameless: true, transparent: true, floating: true, clickThrough: true });

process.on('SIGTERM', () => win.close());
```

### 10. Image / Chart Display

Show a generated chart or image.

```js
const win = open(`
<body style="margin: 0; background: white;">
  <canvas id="chart"></canvas>
  <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
  <script>
    new Chart(document.getElementById('chart'), {
      type: 'bar',
      data: {
        labels: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'],
        datasets: [{ label: 'Commits', data: [12, 19, 3, 5, 8], backgroundColor: '#4299e1' }]
      }
    });
  </script>
</body>
`, { width: 500, height: 350, title: 'Weekly Commits' });
```

### 11. Frosted Glass Command Palette

A frameless, transparent search/command palette.

```js
const result = await prompt(`
<body style="margin: 0; background: transparent !important;">
  <style>
    .palette {
      background: rgba(30,30,40,0.9); border-radius: 12px; overflow: hidden;
      backdrop-filter: blur(30px); -webkit-backdrop-filter: blur(30px);
      border: 1px solid rgba(255,255,255,0.1); font-family: system-ui;
    }
    input {
      width: 100%; padding: 16px 20px; font-size: 16px; border: none;
      background: transparent; color: white; outline: none;
      border-bottom: 1px solid rgba(255,255,255,0.1);
    }
    input::placeholder { color: #666; }
    .results { max-height: 200px; overflow-y: auto; }
    .result {
      padding: 10px 20px; color: #ccc; cursor: pointer; display: flex;
      justify-content: space-between; font-size: 14px;
    }
    .result:hover, .result.active { background: rgba(66,153,225,0.3); color: white; }
    .result .hint { color: #666; font-size: 12px; }
  </style>
  <div class="palette">
    <input id="q" placeholder="Type a command..." autofocus />
    <div class="results" id="results"></div>
  </div>
  <script>
    const commands = [
      {name: 'New File', hint: '⌘N'},
      {name: 'Open Terminal', hint: '⌘T'},
      {name: 'Run Tests', hint: '⌘R'},
      {name: 'Git Commit', hint: '⌘K'},
      {name: 'Search Files', hint: '⌘P'},
    ];
    let filtered = [...commands], active = 0;
    function render() {
      document.getElementById('results').innerHTML = filtered.map((c, i) =>
        '<div class="result' + (i===active?' active':'') + '" onclick="pick('+i+')">' +
        c.name + '<span class="hint">' + c.hint + '</span></div>'
      ).join('');
    }
    function pick(i) { window.glimpse.send(filtered[i]); }
    document.getElementById('q').addEventListener('input', e => {
      const q = e.target.value.toLowerCase();
      filtered = commands.filter(c => c.name.toLowerCase().includes(q));
      active = 0; render();
    });
    document.addEventListener('keydown', e => {
      if (e.key === 'ArrowDown') { active = (active+1) % filtered.length; render(); e.preventDefault(); }
      if (e.key === 'ArrowUp') { active = (active-1+filtered.length) % filtered.length; render(); e.preventDefault(); }
      if (e.key === 'Enter' && filtered.length) pick(active);
      if (e.key === 'Escape') window.glimpse.send(null);
    });
    render();
  </script>
</body>
`, { width: 400, height: 300, frameless: true, transparent: true });
```

---

## Tool conventions cheat sheet

| Need | Tool | Notes |
|---|---|---|
| Write the .mjs script | `Write` | Save to `/tmp/<name>.mjs` |
| One-shot dialog (blocking) | `Bash` (foreground) | stdout = `JSON.stringify(answer)` |
| Persistent window | `Bash` with `run_in_background: true` | Returns task id + `.output` path |
| Read window output / messages | `Read` the `.output` path, or `TaskOutput` | Background stdout isn't auto-injected |
| Close persistent window | `TaskStop` | Or let script close itself |
| Test runtime | `node` | ESM modules, requires Node 18+ |

---

## Creative ideas

Use `win.info` for screen dimensions and dark mode awareness:

- **Diff viewer** — side-by-side diff before committing
- **Color picker** — HTML color input + preview, return the hex
- **File browser** — list files with icons, click to select
- **Approval flow** — show generated code syntax-highlighted, approve/reject
- **Multi-step wizard** — use `.setHTML()` to swap content between steps in one window
- **Screenshot annotation** — load an image, draw/click to mark areas
- **Kanban board** — drag-and-drop tasks (see the `glimpse-task-board` skill for a working example)
- **Terminal overlay** — transparent floating output on top of the user's work
- **System monitor** — tiny floating CPU/memory widget, push updates via `.send()`
- **Emoji picker** — grid, click to select, return the character
- **Pomodoro timer** — floating transparent countdown
- **Adaptive theming** — read `win.info.appearance.darkMode` and style accordingly
- **Multi-monitor aware** — use `win.info.screens` to position on a specific display

---

## Tips

- **Always set `cursor: pointer`** on clickable elements.
- **Use `autofocus`** on the primary input field.
- **Add keyboard shortcuts** — Enter to confirm, Escape to cancel.
- **For transparent windows**, set `background: transparent !important` on `<body>` and use a styled container with `border-radius` for rounded corners.
- **Backdrop blur** (`backdrop-filter: blur(20px)`) makes transparent windows look native.
- **`win.send()` accepts any JS string** — use it to push live data into the webview.
- **`prompt()` returns `null`** when the user closes without sending — always handle this case.
- **Be generous with window height** — content clips silently if the window is too short. A form with two inputs + buttons needs ~300px, not 200px.
- **Keep windows small** — Glimpse is for focused interactions, not full apps.
- **Quote your HTML carefully** when embedding it in a JS template string within another shell command. Easier to `Write` the script to disk than wrestle with `node -e`.

### Windows caveats (only relevant if you're on Windows; Doug's machine is macOS)

- ESM imports need `file:///C:/...` URLs for absolute paths. Bare paths fail with `ERR_UNSUPPORTED_ESM_URL_SCHEME`.
- Inline `onclick="..."` handlers can be unreliable in WebView2 — prefer `addEventListener`.
- Use `floating: true` for sequential prompts so later windows don't appear behind earlier ones.
