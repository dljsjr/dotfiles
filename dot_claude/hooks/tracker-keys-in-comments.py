#!/usr/bin/env python3
"""PostToolUse guard: catch task-tracker keys (DG-72, PCCP-11, JIRA-1234, …)
left in *comments* of newly written code.

Language-agnostic by heuristic, not by parser: it only inspects lines that
look like comments (a comment marker at the start of the trimmed line, or a
spaced inline `// # --` marker), so a URL like `https://x/DG-1` inside a
string on a normal code line is not flagged. Tracker keys are matched by
shape and filtered against a denylist of common tech acronyms / model names
(UTF-8, SHA-256, GPT-4, …) so those don't read as tickets.

Warn-only: emits a PostToolUse `decision: block` whose `reason` is fed back
to the model so it fixes the comment and continues — it never hard-stops a
turn. Tune via env:
  CLAUDE_TRACKER_KEYS   comma-separated ALLOWLIST of prefixes (e.g. "DG,PCCP").
                        When set, ONLY these prefixes are flagged — precise,
                        zero false positives. Overrides the denylist.
  CLAUDE_TRACKER_DENY   extra comma-separated prefixes to ignore (added to the
                        built-in denylist). Ignored when the allowlist is set.
"""

import json
import os
import re
import sys

# A tracker-key shape: 2–9 leading uppercase alnum (starting with a letter),
# a hyphen, then digits. Single-letter prefixes are excluded on purpose
# (avoids "T-1000", "H-1B", model "o-1", etc.).
KEY = re.compile(r"\b([A-Z][A-Z0-9]{1,8})-[0-9]+\b")

# Prefixes that are decidedly NOT ephemeral trackers: tech acronyms, model
# families, and DURABLE committed references (ADR/RFC/PEP) — the latter are
# stable citations that belong in doc comments, unlike task tickets.
DENY = {
    "UTF", "SHA", "ISO", "IEC", "RFC", "CVE", "ANSI", "IEEE", "PEP", "ECMA",
    "ITU", "AES", "RSA", "MD", "IPV", "MP", "GPT", "CLAUDE", "LLAMA", "GEMINI",
    "ES", "RS", "HS", "PS", "EC", "SS", "WCAG", "PCI", "FIPS", "NIST", "CSS",
    "HTML", "HTTP", "OAUTH", "TLS", "SSL", "X", "COVID", "ISBN", "EAN", "UPC",
    "ADR", "RFD",  # durable committed decision records — cite these freely
}

# Comment-marker prefixes: if the trimmed line starts with one of these, the
# whole line is treated as a comment.
LINE_PREFIXES = ("///", "//!", "//", "/*", "<!--", "--", ";;", ";")
# `#` and `*`-lead are comments in code but headers/bullets in prose, so they
# only count as comment starts outside prose files.
PROSE_EXTS = {".md", ".markdown", ".mkd", ".rst", ".txt", ".adoc"}
# Inline (trailing) comment markers — matched only when whitespace-flanked so
# `https://`, `a#b`, `x--y` in code don't register.
INLINE = re.compile(r"(?:^|\s)(//+|/\*|<!--|#|--|;)\s")


def new_text(tool_name: str, ti: dict) -> str:
    """The text this tool call is *adding* — we only police new content."""
    if tool_name == "Write":
        return ti.get("content", "") or ""
    if tool_name == "Edit":
        return ti.get("new_string", "") or ""
    if tool_name == "MultiEdit":
        return "\n".join(e.get("new_string", "") or "" for e in ti.get("edits", []))
    return ""


def allowed(prefix: str, allowlist: set[str], deny: set[str]) -> bool:
    """True if this prefix should be FLAGGED (i.e. treated as a tracker key)."""
    if allowlist:
        return prefix in allowlist
    return prefix not in deny


def comment_span(line: str, is_prose: bool) -> str | None:
    """Return the comment portion of `line`, or None if it isn't a comment."""
    stripped = line.lstrip()
    starts = LINE_PREFIXES + (() if is_prose else ("#", "*"))
    if stripped.startswith(starts):
        return stripped
    m = INLINE.search(line)
    return line[m.start():] if m else None


def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        return 0  # never break the tool on a malformed payload
    ti = payload.get("tool_input") or {}
    text = new_text(payload.get("tool_name", ""), ti)
    if not text:
        return 0
    path = ti.get("file_path", "")
    is_prose = os.path.splitext(path)[1].lower() in PROSE_EXTS

    allowlist = {p.strip().upper() for p in os.environ.get("CLAUDE_TRACKER_KEYS", "").split(",") if p.strip()}
    deny = DENY | {p.strip().upper() for p in os.environ.get("CLAUDE_TRACKER_DENY", "").split(",") if p.strip()}

    hits: list[str] = []
    for i, line in enumerate(text.splitlines(), 1):
        span = comment_span(line, is_prose)
        if span is None:
            continue
        for m in KEY.finditer(span):
            if allowed(m.group(1), allowlist, deny):
                hits.append(f"  line {i}: {m.group(0)}  in  {line.strip()[:100]}")

    if not hits:
        return 0
    where = f" in {path}" if path else ""
    reason = (
        f"Task-tracker key(s) left in comment(s){where} — these render into docs, "
        "go stale, and don't belong in committed source. Put ticket linkage in the "
        "commit message (Refs:) instead, and remove or rephrase these:\n"
        + "\n".join(hits)
    )
    print(json.dumps({"decision": "block", "reason": reason}))
    return 0


if __name__ == "__main__":
    sys.exit(main())
