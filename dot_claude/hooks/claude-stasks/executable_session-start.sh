#!/usr/bin/env bash
# SessionStart hook — surface IN_PROGRESS sandpiper tasks for this project
# as additionalContext so the agent can mirror them into harness Tasks by
# creating [KEY]-marked tasks itself (routed by the TaskCreated hook).
#
# History (2026-07-25 rework): this script used to write harness task
# files directly into ~/.claude/tasks/<session_id>/ and predict the ids
# the harness would assign, recording those guesses in the session
# mapping. The harness no longer reads that directory, so the mirror
# silently did nothing while the fabricated mappings could mis-route
# TaskCompleted onto unrelated sandpiper tasks. Context-only is the
# supported surface; never write the harness's private store.
#
# Skipped silently if:
#   - cwd is not under a .sandpiper/tasks/ directory
#   - sandpiper-tasks CLI not found
#   - no IN_PROGRESS sandpiper tasks for this project

set -uo pipefail

source "$(dirname "$0")/lib.sh"

input="$(cat)"

session_id="$(jq -r '.session_id // empty' <<<"${input}")"
cwd="$(jq -r '.cwd // empty' <<<"${input}")"

[[ -z "${session_id}" ]] && exit 0
[[ -z "${cwd}" ]] && exit 0

if ! project_root="$(find_sandpiper_root "${cwd}")"; then
    exit 0
fi

if ! cli="$(sandpiper_tasks_bin)"; then
    exit 0
fi

# IN_PROGRESS sandpiper tasks, machine-readable.
in_progress_json="$("${cli}" --dir "${project_root}" --format json task list -s IN_PROGRESS 2>/dev/null || echo '[]')"
count="$(jq 'length' <<<"${in_progress_json}" 2>/dev/null || echo 0)"
[[ "${count}" == "0" ]] && exit 0

task_lines="$(jq -r '
    .[] | "[\(.priority // "?")] \(.key) (\(.kind // "TASK")): \(.title) @\(.assignee // "UNASSIGNED")"
' <<<"${in_progress_json}" 2>/dev/null)"

context="Sandpiper tasks currently IN_PROGRESS in this project (.sandpiper/tasks/):

${task_lines}

To resume one, create a harness task whose subject starts with its marker, e.g. TaskCreate(subject: \"[PCCP-12] <title>\") — the TaskCreated hook mirrors lifecycle to sandpiper-tasks automatically. Tasks not being worked on this session need no mirroring."

emit_hook_output "SessionStart" "${context}"

exit 0
