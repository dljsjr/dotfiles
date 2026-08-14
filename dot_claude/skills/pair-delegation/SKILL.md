---
name: pair-delegation
description: >-
  Coordinates model-tiered coding delegation through pair-developer and pair-reviewer subagents:
  prepared briefs, peer review, change-ID handoffs, check-ins, acceptance, and teardown. Use only
  when the user invokes /pair-delegation; do not load automatically.
compatibility: >-
  Claude Code with named subagents, SendMessage, TaskStop, and isolated jj workspaces or Git
  worktrees.
disable-model-invocation: true
---

# Pair delegation

## Tier policy

| Main model | Coding arrangement |
| --- | --- |
| Opus/Fable | Sonnet `pair-developer` (`high`) + Sonnet `pair-reviewer` (`xhigh`); main coordinates and accepts but does not code |
| Sonnet | Main codes; spawn only `pair-reviewer` |
| Haiku | Exempt |

Use one pair per parallel workstream. Review every change, however mechanical; pair convergence is
necessary but the coordinator owns final acceptance. “Faster if I do it myself” is not an
exception because delegation preserves high-tier budget.

The main agent may code work whose design genuinely emerges during implementation—novel architecture
or subtle invariant surgery—only with per-instance user approval. Mechanical work never qualifies.

## Run a pair

1. Prepare a standalone written task and any binding design material before spawning; subagents do
   not inherit chat context.
2. Give long-running streams isolated workspaces. Name each pair by stream (`dev-1`/`rev-1`) and tell
   both agents their counterpart's name.
3. Brief both halves symmetrically: every constraint, hazard, verification requirement, and mutating
   command disclosed to one goes to the other.
4. Set a check-in cadence in both spawn prompts: 10 minutes for tight loops, 30–60 minutes for long
   builds or measurements. Require an expected-report time before work that outlives a turn and make
   long-running drivers compose the delivery message, not only write a result file.
5. Let findings and fixes travel peer-to-peer via `SendMessage`. Both agents report terminal outcomes
   to you; independently verify the accepted tip end-to-end.

Subagents are turn-driven: silence does not distinguish work, idleness, or failure. Require them to
drain their inbox before composing status. If a reminder is needed, use one task-sized scheduled
wake-up, then ask directly. Never infer liveness with `tail -f`, unbounded polling loops, or
filesystem mtimes.

## Review handoff

### jj repositories

1. The developer works in a dedicated change.
2. After final verification, the developer advances with `jj commit -m "DESCRIPTION"` or `jj new`,
   verifies `jj st` is clean, and sends only the submitted change's change ID.
3. In an isolated workspace, the reviewer runs
   `jj new -r CHANGE_ID -m "review CHANGE_ID"`, then verifies `@-` has that change ID and contains
   the named artifacts.
4. Neither agent rewrites a submitted change during its active review. Corrections go in a new
   descendant change, which is advanced from and submitted by its own change ID.
5. Acceptance covers the latest submitted change and its ancestors. After acceptance, squash, leave,
   or rearrange the changes as needed.

### Pure Git repositories

Submit an immutable commit SHA, never a branch. The reviewer checks that SHA out in an isolated
worktree. Do not amend, rebase, or force-push a reviewed range; add correction commits and clean up
at merge.

Use freezes only for shared machine resources; a freeze binds its declarer first. Build first, get
an explicit “I am idle” from the other half, then freeze and measure; compiles, tests, profilers, and
`jj diff` add load. Do not measure controls or timing against a target still being edited.

## Verification discipline

- Reproduce claims and numbers from artifacts before repeating them; an unverified agent claim
  becomes yours when reported.
- Detection and attribution are independent claims and need independent evidence.
- Show every check can fail. Use positive controls on green results; require negative controls to
  fail with a pre-registered signature; assert that each A/B arm reached the regime it grades.
- Treat instruments as likely error sources: state what direction each discriminates, do not stack
  profilers, and scrutinize favorable results as hard as unfavorable ones.
- `n=1` does not establish a grade; demonstrate the noise floor and apply thresholds only in the
  configuration where derived. Stop sampling once a result is decisive.
- Re-derive a recorded number when it becomes load-bearing for a new decision. Write “not measured,”
  not “unchanged,” when no measurement exists.
- Prefer sealed or blinded predictions with explicit refutation conditions. Reasoned abstention is
  valid.

## Messages must converge

Write state-conditional orders that remain correct if they arrive late. To stop an oscillation, send
one terminal order naming the target state and voided prior instructions, then send nothing further
on it. Immediately before a long run or terminal action (commit, push, teardown), check the inbox and
mtime of binding documents.

## Teardown

Before ending a turn in which a stream finished, and before session end, reap all three resource
classes:

1. Stop every spawned agent by name with `TaskStop`.
2. Stop background shells by ID, then verify at the OS level with
   `ps ax | grep -E 'tail -f|while true'` for orphaned watchers.
3. Remove isolated workspaces. For jj, run both `jj workspace forget NAME` and `rm -rf DIR`, then
   `jj workspace list` in every repo touched. For Git, use `git worktree remove`, or
   `git worktree prune` after manual deletion.

If multiple workspaces touched one jj change, check for divergence with
`jj log -r 'change_id(CHANGE_ID)'`.

## User reporting

Give one consolidated report per workstream at true completion. Acknowledge intermediate agent pings
in at most one non-conclusive line. Label corrections, assign exactly one filer for each ticket, and
stop if coordination overhead outgrows the landing.
