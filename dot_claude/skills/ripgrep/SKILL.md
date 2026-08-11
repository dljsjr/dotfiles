---
name: ripgrep
description: >
  Read BEFORE running ripgrep (rg) for ANY search. rg's flags diverge sharply from grep's and
  bundling grep-style short flags silently corrupts output rather than erroring. Triggers: any rg
  command, "ripgrep", "rg", "search the codebase", "grep for X", "find in files", recursive search,
  searching a gitignored tree, and ESPECIALLY any urge to type grep-style bundles like -rn / -rl /
  -rin / -rio. Also consult when a search returns garbled/replaced matches, doesn't recurse, or
  gives unexpected/empty output.
---

# ripgrep (rg) — its flags are NOT grep's

## The #1 trap (this has bitten me repeatedly — memorize it)

- **rg recurses by default.** There is no "recursive" flag to add. `grep -r` has no rg equivalent — it's the default.
- **`-r` means `--replace=REPLACEMENT`**, and it **consumes the next token as its value.** So:
  - `rg -rn 'pat' path` → `--replace=n` → rewrites every match to the literal `n` (that's why output looked "munged": `token`→`n`, `C2BD29B7`→`n`).
  - `rg -rl 'pat'` → replace-with-`l`; `rg -rin` → `-i` then `--replace=n`; etc.
- This **does not error** — it produces plausible-looking but wrong output. Environments never munge text; a misparsed `-r` does.
- The grep habit `-rn` (recursive + line-number, both argless in grep) is the bug. **Never type `-r` unless you actually want search-and-replace-in-output.**

## Short flags that TAKE AN ARGUMENT — never bundle, never typo-adjacent

Each consumes the next token, so gluing another letter on is always wrong:

| flag | long | takes |
|---|---|---|
| `-r` | `--replace` | REPLACEMENT string |
| `-e` | `--regexp` | PATTERN (use for patterns starting with `-`) |
| `-g` | `--glob` | GLOB |
| `-t` / `-T` | `--type` / `--type-not` | TYPE |
| `-m` | `--max-count` | NUM |
| `-A`/`-B`/`-C` | after/before/context | NUM (`-C3` or `-C 3` ok; never `-Cx`) |
| `-M` | `--max-columns` | NUM |
| `-E` | `--encoding` | ENCODING |

Traps: `-rn -rl -rin -rio -en -gn -tn -mn`.

## Argless flags — safe to bundle (these behave like grep)

`-i` ignore-case · `-s` case-sensitive · `-S` smart-case · `-w` word · `-v` invert ·
`-F` fixed-strings · `-n`/`-N` line-number on/off · `-o` only-matching · `-c` count(files) ·
`-l` files-with-matches · `-U` multiline · `-P` pcre2 · `-z` search-zip.
Line numbers are **on by default** to a terminal — `-n` is rarely needed.

## grep → rg translation (the divergences that cause bugs)

| intent | grep | rg |
|---|---|---|
| recursive | `grep -r` | (default — add nothing) |
| line numbers | `grep -n` | (default to TTY) |
| **list matching files** | `grep -rl X` | `rg -l X`  ← NOT `-rl` |
| pattern starting with `-` | `grep -e '-->'` | `rg -e '-->'`  or  `rg -- '-->'` |
| fixed/literal string | `grep -F` | `rg -F` |
| count total matches | `grep -o … \| wc -l` | `rg --count-matches` (`-c` counts files) |
| restrict to glob | `grep --include='*.php'` | `rg -g '*.php'` |
| by language type | — | `rg -t php` (`rg --type-list` to see types) |
| context | `grep -C3` | `rg -C3` |
| multiline match | (awkward) | `rg -U` (+ `--multiline-dotall` for `.` across lines) |
| lookaround/backrefs | `grep -P` | `rg -P` |

## This workspace (vultr @core)

`projects/*` is **gitignored**, so `rg` from the repo root silently skips all sub-project code. To search it:
- `cd projects/<name>` then `rg …` (cleanest — ignore rules behave normally inside the sub-repo), or
- `rg --no-ignore-vcs <pat> projects/<name>` — **scope to the specific sub-path**, else you pull in `node_modules/`, `vendor/`, build output.

Other ignore controls: `--hidden` (include dotfiles), `--no-ignore` (ignore ALL ignore files, broader than `--no-ignore-vcs`).

## When unsure about a flag

`rg --help | rg -- '--<name>'` (rg searching its own help) or `man rg`. **Do not infer rg flags from grep** — that's the root cause every time.
