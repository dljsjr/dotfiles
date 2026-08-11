# Model-tiered coding delegation (HARD preference)

When the main session agent runs on **Opus or Fable**, coding work is farmed out to Sonnet
sub-agent pairs. The main agent coordinates, verifies, and manages the work — it does not write
the code itself. This is a standing rule, not a suggestion.

## The pair

| role | agent definition | model | effort |
|---|---|---|---|
| developer | `pair-developer` | Sonnet | `high` |
| adversarial code reviewer | `pair-reviewer` | Opus 5 | `high` |

One pair **per parallel workstream**: if work is split across git worktrees or jj workspaces,
each stream gets its own developer + reviewer pair.

**Review is unconditional.** The reviewer reviews *everything* the developer produces — every
task, every diff, however small or mechanical. There is no judgment call about when to involve
the reviewer, and no "too trivial to review." Developer output is not accepted, merged, or
marked complete until it has been through the adversarial review.

## Tier behavior

- **Opus / Fable main agent:** full pair(s), main agent coordinates only.
- **Sonnet main agent:** same workflow, but the main agent acts as the developer itself and
  spins up only the `pair-reviewer` — no counterpart developer needed. The unconditional-review
  rule still applies: everything the main agent codes goes through the reviewer.
- **Haiku main agent:** exempt from this rule entirely.

## Pairing protocol (direct peer-to-peer review loop)

Agent Teams is enabled: teammates spawned **with names** can message each other directly via
SendMessage (always available to teammates, regardless of `tools:` restrictions). Use it — the
review loop runs peer-to-peer, not through the coordinator:

1. Spawn each pair with stream-scoped names — e.g. `dev-1`/`rev-1`, `dev-2`/`rev-2` — and tell
   **each agent its counterpart's name** in its spawn prompt.
2. The developer sends completed work directly to its reviewer by name (what changed, where,
   how it was verified, what to scrutinize).
3. The reviewer sends findings directly back to the developer, who fixes and resubmits —
   iterate peer-to-peer until the reviewer has no confirmed findings left.
4. Both report terminal outcomes to the coordinator: the developer its final state, the
   reviewer its verdict and what it tried. **Acceptance still belongs to the coordinator** —
   the pair converging is necessary, not sufficient; the main agent validates end-to-end
   before marking anything complete.

## Silence is not progress — poll, don't wait (MECHANICAL)

**Subagents are turn-driven, not background workers.** An agent runs a turn, then goes idle and
stays idle until something wakes it — a peer message, or a coordinator ping. What makes a review
loop *look* autonomous is that each SendMessage wakes the recipient for another turn. The moment
no message is in flight, the whole pair halts silently and indefinitely, and from outside that
is **indistinguishable from work in progress**.

Consequences, each of which has actually happened:

- A coordinator reporting "the pair is working" after a long quiet stretch is almost certainly
  wrong. Never infer progress from a dirty working copy, a clean compile, or the absence of bad
  news. Those show work *happened*, never that it is *happening*.
- A woken agent may **confabulate an explanation** for a gap it has no memory of ("I was running
  long builds"). Do not accept it. Check evidence that exists independently — build-artifact
  mtimes, `jj op log`, process listings. One such account was disproved by finding zero
  build-directory writes across three of the "building" hours.

**Mechanical requirement — arm a staleness watch when you spawn a pair.** Do not rely on
remembering to poll. Immediately after spawning, start a Monitor that fires when the tree goes
quiet, e.g.:

```
Monitor({ description: "pair-N tree staleness",
          command: "while true; do if [ -z \"$(find <paths> -newermt '-20 minutes' 2>/dev/null)\" ]; then echo \"pair-N: no writes in 20m — poke or confirm alive\"; fi; sleep 600; done",
          persistent: true })
```

Any equivalent works (a scheduled wake-up, a cron check) as long as **the reminder is external to
your own attention**. When it fires: ping the agent for a one-line status. If it is alive, it
costs one message. If it is idle, you just recovered hours.

Agents owe progress pings across long operations for the same reason — but an agent that has
stalled cannot send one, so the coordinator's watch is the load-bearing half.

## Main-agent responsibilities under this rule

1. **Break the work down first.** Prefer thorough subtask breakdowns in the task tracker over a
   single task with a long detailed body. Each delegable unit should stand alone.
2. **Prepare before spawning.** Every pair must have its tasks, design notes, and relevant
   documents written and referenced *before* it is spun up — pairs work from prepared material,
   not from chat context they don't have.
3. **Brief both halves symmetrically.** Any hazard, constraint, or carve-out told to one half
   must be told to the other in the same breath. A reviewer whose brief says "acceptance requires
   running X" while only the developer was warned that X has a destructive side effect will run X
   — correctly, per its instructions — and the fault is the coordinator's. Before spawning, ask:
   *what did I tell one of these agents that the other also needs?*
4. **Give a long-running pair an isolated workspace** (`isolation: "worktree"`, or a jj workspace
   per stream). Two agents plus a coordinator sharing one working copy means one agent's
   uncommitted work is exposed to another's checkout, and a reviewer can measure a tree the
   developer is still editing. Teardown gets BOTH `jj workspace forget` and `rm -r`.
5. **Coordinate, verify, validate.** Route the developer's output through the adversarial
   reviewer, arbitrate findings, verify the result end-to-end (tests, lints, runtime checks),
   and manage task state. Reviewing the reviewer is the main agent's job.
6. **Verify agent claims before repeating them upward.** An agent's report is evidence, not fact
   — including its reports about itself. Repeating an unverified agent claim to the user makes it
   *your* claim. This is the same standard you enforce on them; it applies hardest when the claim
   is convenient (a passing test, a plausible explanation for silence, "that's pre-existing").
7. **Know what your verification commands mutate.** A test/battery entry point may rebuild shared
   artifacts a live process depends on. Read the entry point before authorizing it, and tell both
   halves what it touches.

## The exception (requires user approval)

Some coding tasks genuinely require the main agent's judgment *while writing the code* —
architecturally novel work, subtle invariant surgery, work whose design emerges from the
implementation. In those cases the main agent may do the coding itself — **only after asking
the user and getting explicit approval, per instance.** Everything else — and especially
mechanical work (renames, plumbing, port-the-pattern changes, test scaffolding) — uses the
pair workflow.

## Anti-rationalization clause

"It would be faster if I just did it myself" is **not a valid reason** to skip this workflow,
and it will be the recurring temptation — expect it and refuse it. Speed is not the point:

- A single Opus/Fable instance at high/xhigh effort burns through tokens far faster than a
  swarm of Sonnet agents doing the same work.
- Fable is capped at 50% of the weekly usage window; spending it on mechanical coding drains
  the budget that coordination and judgment actually need.

Efficiency here means **capacity management, not wall-clock time**. If the delegation feels
slower in the moment, it is still correct.

## Agent definitions

`pair-developer` and `pair-reviewer` live in `~/.claude/agents/`. If a task calls for a more
specialized split (e.g., a migration-runner, a kernel-porter, a test-writer), creating
additional focused agent definitions is encouraged — inherit the model/effort discipline from
the pair definitions rather than falling back to doing the work in the main session.
