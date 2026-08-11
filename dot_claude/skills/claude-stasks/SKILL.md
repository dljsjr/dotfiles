---
name: claude-stasks
description: >
  Bridge between Claude Code's session-scoped Task tracker (TaskCreate /
  TaskUpdate / TaskCompleted) and project-scoped sandpiper-tasks (PCCP-N,
  SHR-N, etc. living in .sandpiper/tasks/). Use this skill whenever the
  current project has a .sandpiper/tasks/ directory AND you're using the
  built-in Tasks tracker. The skill explains the marker convention that
  routes harness Task lifecycle events to sandpiper-tasks state changes
  via configured hooks.

  Triggers: any session that's working in a project with a
  `.sandpiper/tasks/` workspace; any time you call TaskCreate or update
  task status; "sandpiper task", "PCCP-", "track this in sandpiper",
  "[PCCP-", "[+PCCP", "[+sub PCCP-", "persist this plan", "[persist as".
  Also trigger when the SessionStart hook surfaces an "IN_PROGRESS in
  this project" pulse — those tasks are the ones to mirror.
---

# claude-stasks — Unifying Claude Code Tasks with Sandpiper Tasks

Claude Code has two parallel task-like surfaces that have historically
required separate management:

- **Built-in Tasks** (TaskCreate / TaskUpdate / TaskCompleted) —
  session-scoped, ephemeral, in-flight progress for the current session.
- **Sandpiper-tasks** (the `sandpiper-tasks` CLI, files under
  `.sandpiper/tasks/`) — project-scoped, durable across sessions, the
  authoritative project work tracker.

This skill defines a marker convention that routes harness Task events
to sandpiper-tasks state changes via three configured hooks
(TaskCreated, TaskCompleted, SessionStart), plus a Plan-mode integration
(ExitPlanMode hook). When you follow the convention, the harness Task
and the sandpiper task stay in sync without manual `sandpiper-tasks`
invocations.

## When to apply

Apply this skill when **all three** are true:

1. The current project has a `.sandpiper/tasks/` directory in scope
   (the SessionStart hook surfaces a pulse if it does).
2. You're about to call `TaskCreate` or `TaskUpdate { status: completed }`
   to track work for the session.
3. The work corresponds to (or should correspond to) a project-level
   sandpiper task.

If any of those is false, just use harness Tasks normally — no marker,
no mirroring. The hooks are no-ops when no marker is present.

## The marker convention

Markers go in the harness Task's title (or description / activeForm —
the hook scans common string fields). Three forms:

### `[PCCP-12]` — pickup an existing sandpiper task

```text
TaskCreate(content="[PCCP-12] Implement parking coordinator and cancellation listener", ...)
```

The hook calls `sandpiper-tasks task pickup PCCP-12`, transitioning
that sandpiper task from NOT_STARTED → IN_PROGRESS. Use this when
you're picking up a task that's already in the backlog.

### `[+PCCP]` — create a new top-level sandpiper task

```text
TaskCreate(content="[+PCCP] Refactor token rotation logic", ...)
```

The hook calls `sandpiper-tasks task create -p PCCP -t "Refactor token rotation logic"`,
captures the assigned key (e.g., PCCP-14), pickups it, and replies with an
ACTION REQUIRED context telling you to rewrite the harness Task's subject to
`[PCCP-14] Refactor token rotation logic` via TaskUpdate — do that immediately
so the canonical key is embedded for subsequent operations. (The hook cannot
rename the harness task itself; TaskCreated is a post-hoc notification.)

Use this for genuinely new top-level work that should be tracked
durably. Don't use it for ephemeral session steps (those should be
unmarked harness Tasks).

### `[+sub PCCP-12]` — create a new sandpiper subtask under a parent

```text
TaskCreate(content="[+sub PCCP-12] Wire stream-json reader into the per-turn select loop", ...)
```

The hook calls `sandpiper-tasks task create -p PCCP -t "..." -k SUBTASK --parent PCCP-12`,
pickups the new subtask. Use this for steps that decompose an
in-progress parent task and deserve their own durable tracking.

### No marker

If no marker is present, the harness Task is purely session-scoped.
The hooks see no marker and do nothing. Use this for ephemeral session
state that doesn't need cross-session persistence (subtasks of
implementation work, mid-session checkpoints, etc.).

## Lifecycle: what happens at each event

| Event | With marker (or with mapping) | Without marker / mapping |
|-------|-------------|----------------|
| TaskCreated | Hook does the appropriate sandpiper operation (pickup/create), records mapping for later events | No-op |
| TaskUpdate (description / activeForm / content / body field) | Hook calls `task update <key> --desc "..."` to mirror the new body to the sandpiper task | No-op |
| TaskUpdate (status only, no body field) | No-op (TaskCompleted handles status: completed; other status changes don't need mirroring today) | No-op |
| TaskCompleted | Hook calls `task complete <key>` (NOT_STARTED → NEEDS REVIEW) | No-op |
| Final close (`task complete --final --resolution DONE`) | **Manual.** "Needs review" is a meaningful workflow boundary. | n/a |

**The session-scoped mapping** is stored at
`~/.claude/hooks/claude-stasks/data/sessions/<session_id>.json` —
the TaskCompleted hook reads this to know which sandpiper key to close.
You don't interact with the file directly; the hooks manage it.

## When to use each marker form

A practical rubric:

- Implementing a planned PCCP task: `[PCCP-N]` (pickup existing).
- Discovering work that wasn't in the backlog and should be tracked:
  `[+PCCP]` (create new top-level).
- Breaking a complex in-progress task into trackable steps:
  `[+sub PCCP-N]` (create subtask).
- Routine session bookkeeping (e.g., "read these three files"): no
  marker.

When in doubt, no marker. It's easier to add a marker later (file the
sandpiper task by hand and pickup with `[PCCP-N]` next session) than
to clean up an over-mirrored backlog.

## Plan-mode integration

Two-way integration: planning **inputs** (existing project artifacts)
flow into plan mode automatically, and planning **outputs** (your plan
text) can be persisted back to disk on demand.

### EnterPlanMode: surfacing the project's planning trinity

When you enter plan mode in a project that has a `.sandpiper/docs/`
directory, the EnterPlanMode hook surfaces the project's existing
planning artifacts as `additionalContext` so your plan can be informed
by and consistent with what's already documented.

The hook recognizes the **PRD / Spec / Work Plan trinity convention**:

| File pattern | Role | Content |
|---|---|---|
| `*-prd.md` | **PRD** — why we're doing this | Motivations, goals, constraints, success criteria, **and a decision log** capturing the rationale for non-obvious design choices. The "why" anchor of the trinity. |
| `*-spec.md` | **Spec** — what we're building | Architecture, surfaces, contracts, test matrix. The authoritative reference for "what does this system do?" |
| `*-work-plan.md` | **Work Plan** — how we'll build it | Phases with explicit gates, time estimates, risks, sequencing. Reads like "if you implemented this serially, here's the order." |
| `HANDOFF.md` | Orientation | Where to start reading; one-paragraph state-of-the-project. Optional but useful for handoffs. |

**Legacy variant**: a standalone `*-decisions.md` file is recognized
under the PRD category. This shape happens when the design rationale
was captured separately from a PRD (e.g., the design conversation
happened in a different context). Treat it as a PRD-equivalent for
planning purposes; in new projects, prefer integrating the decision
log into the PRD itself.

Plus any other `.md` files in `.sandpiper/docs/` get listed under
"Other artifacts" — typically verification notes, investigation docs,
amendments to the spec or work plan.

### When entering plan mode in a trinity-bearing project

1. **Read the existing artifacts first.** Your plan should be
   consistent with them or explicitly amend them. Don't propose
   architectures that contradict the PRD's decision log without
   addressing the rationale captured there.
2. **Structure your plan to fit the convention.** Sections like
   motivation (PRD-flavored why + decision-log entry), what changes
   (Spec-flavored), how (Work Plan phases / gates), and what stays.
   Mirroring the trinity's framing makes your plan slot into the
   existing doc family naturally.
3. **Propose new artifacts when warranted.** If your plan introduces
   non-trivial new direction:
   - New rationale that future readers will want → extend the PRD's
     decision log with a new entry.
   - Architectural pivots → propose a focused investigation doc like
     `-blocking-mcp.md` (an amendment that supersedes part of the spec)
     or `-hook-dispatch.md` (an investigation that motivates a pivot).
   - New work scope → propose work-plan amendments (new phases,
     re-scoped phases).
4. **Tag durable plans for persistence** with `[persist as: <slug>]`
   so the ExitPlanMode hook saves them under
   `.sandpiper/docs/plans/`. See below.

### ExitPlanMode: persisting plans on demand

Plans built in plan mode are by default ephemeral session reasoning.
If a plan represents durable architectural decisions or an
implementation sketch that future sessions should reference, mark it
for persistence:

```text
[persist as: refactor-parking-coordinator]
```

Place the marker anywhere in the plan text. When the
ExitPlanMode hook sees it:

1. Strips the marker from the plan body.
2. Writes the plan to
   `<project_root>/.sandpiper/docs/plans/YYYY-MM-DD-<slug>.md` with
   a small YAML frontmatter (title, created timestamp, kind: plan).
3. Passes the plan through to ExitPlanMode unchanged (the user still
   sees the plan in plan-mode output).

When to add `[persist as: ...]`:

- The plan describes architecture or a non-trivial multi-step
  implementation that future-you will want to revisit.
- The plan involves decisions or trade-offs that informed the design
  but won't be obvious from the resulting code.
- The work the plan describes spans multiple sessions.

When to skip the marker:

- The plan is a quick "let me look at three files first" sketch.
- The work will obviously be reflected in the code itself.
- The plan is exploratory ("considering X, Y, Z") without committing
  to one direction.

The slug should be a kebab-case short name. Don't include the date —
the hook prepends it.

## SessionStart awareness pulse

When you start a new session in a project with a `.sandpiper/tasks/`
workspace, the SessionStart hook runs `sandpiper-tasks task list -s
IN_PROGRESS` and surfaces the result as `additionalContext`. You'll
see something like:

```text
Sandpiper tasks currently IN_PROGRESS in this project (.sandpiper/tasks/):

[HIGH] PCCP-11 (TASK): Refactor MCP server: ParkingCoordinator, cancellation listener, annotation policy [IN PROGRESS] @AGENT
...

To resume work on one, create a harness task with marker like `[PCCP-N]` in the title — it'll automatically mirror to sandpiper.
```

Use the pulse to decide whether to resume an in-progress task or
acknowledge it's not the focus of this session and continue.

If no IN_PROGRESS tasks exist, the pulse is silent (no spurious
output).

## Common patterns

### Picking up a planned task

```
1. SessionStart pulse: "PCCP-11 is IN_PROGRESS"
2. TaskCreate(content="[PCCP-11] Refactor MCP server: parking coordinator + cancellation + annotation policy", ...)
   → hook picks up PCCP-11 (already IN_PROGRESS, idempotent)
3. ... do the work ...
4. TaskUpdate(task_id, status="completed")
   → hook marks PCCP-11 → NEEDS REVIEW
5. Manually: sandpiper-tasks task complete --final --resolution DONE PCCP-11 (after Doug reviews)
```

### Creating a new top-level task mid-session

```
1. ... discover that token rotation needs refactoring ...
2. TaskCreate(content="[+PCCP] Refactor token rotation logic", ...)
   → hook creates PCCP-14, pickups it, replies "ACTION REQUIRED: rename to [PCCP-14] ..."
3. TaskUpdate(task_id, subject="[PCCP-14] Refactor token rotation logic")
4. ... do the work ...
5. TaskUpdate(task_id, status="completed")
   → hook marks PCCP-14 → NEEDS REVIEW
```

### Decomposing an in-progress task into subtasks

```
1. Already working on PCCP-12 (mirrored at session start).
2. TaskCreate(content="[+sub PCCP-12] Wire stream-json reader", ...)
   → hook creates PCCP-15 as SUBTASK of PCCP-12, pickups it.
3. TaskCreate(content="[+sub PCCP-12] Implement result queue", ...)
   → hook creates PCCP-16 as another SUBTASK of PCCP-12, pickups it.
4. ... do the work, mark each subtask complete as it finishes ...
```

## Failure modes

- **Marker references nonexistent sandpiper task**: hook fails with
  exit 2, blocks the harness TaskCreate. Stderr explains. Fix by
  using a valid key or `[+PROJECT]` to create.
- **No `.sandpiper/tasks/` in scope**: hook fails with exit 2 if a
  marker is present (you intended to mirror but there's no workspace).
  Without a marker, hook is silent.
- **`sandpiper-tasks` CLI missing or not executable**: hook fails
  with exit 2. Set `SANDPIPER_TASKS_BIN` env var or install the
  bundled CLI.
- **CC version drift on the harness Task input shape**: the hook
  scans common field names and falls back to scanning all string
  values for the marker. If a future version moves things around,
  the marker pattern still matches.

## Configuration locations

- Hook scripts: `~/.claude/hooks/claude-stasks/*.sh`
  - `task-created.sh` — TaskCreated handler
  - `task-update.sh` — PreToolUse on TaskUpdate (body sync)
  - `task-completed.sh` — TaskCompleted handler
  - `session-start.sh` — SessionStart awareness pulse
  - `enter-plan-mode.sh` — PreToolUse on EnterPlanMode (trinity surfacing)
  - `exit-plan-mode.sh` — PreToolUse on ExitPlanMode (persist on marker)
  - `lib.sh` — shared helpers (sourced by the rest)
- Skill (this file): `~/.claude/skills/claude-stasks/SKILL.md`
- Hook registration: `~/.claude/settings.json` (under `hooks`)
- Per-session mappings: `~/.claude/hooks/claude-stasks/data/sessions/<session_id>.json`
- Persisted plans: `<project_root>/.sandpiper/docs/plans/YYYY-MM-DD-<slug>.md`
- Sandpiper-tasks CLI: `~/.claude/skills/tasks/scripts/sandpiper-tasks` (overridable via `SANDPIPER_TASKS_BIN`)
