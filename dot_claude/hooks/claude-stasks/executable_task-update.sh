#!/usr/bin/env bash
# PreToolUse hook on TaskUpdate — mirror harness Task body changes
# (description / activeForm / content) to the corresponding sandpiper
# task's body. Status-only updates (status: completed) are handled by
# TaskCompleted instead.

set -uo pipefail

source "$(dirname "$0")/lib.sh"

input="$(cat)"

# Must be a TaskUpdate call (the matcher in settings.json should already
# constrain this, but be defensive).
tool_name="$(jq -r '.tool_name // empty' <<<"${input}")"
if [[ "${tool_name}" != "TaskUpdate" ]]; then
    exit 0
fi

session_id="$(jq -r '.session_id // empty' <<<"${input}")"
cwd="$(jq -r '.cwd // empty' <<<"${input}")"

# The exact field name for the task identifier in TaskUpdate's input
# isn't 100% documented across CC versions. Try a few likely names.
task_id="$(jq -r '
    .tool_input.task_id //
    .tool_input.taskId //
    .tool_input.id //
    empty
' <<<"${input}")"

if [[ -z "${task_id}" ]]; then
    # Can't identify the task — silently skip.
    exit 0
fi

# Extract any body-like field that's being updated. We treat "description"
# as the canonical body; activeForm and content are common alternates.
new_body="$(jq -r '
    .tool_input.description //
    .tool_input.content //
    .tool_input.body //
    .tool_input.activeForm //
    empty
' <<<"${input}")"

# If no body-like field is in this update, this is a status-only or
# metadata-only change — let TaskCompleted (or no hook) handle it.
if [[ -z "${new_body}" ]]; then
    exit 0
fi

# Look up the sandpiper key for this harness task. If the task wasn't
# mirrored at creation (no marker), there's nothing to sync.
sandpiper_key="$(mapping_get "${session_id}" "${task_id}" || true)"
if [[ -z "${sandpiper_key}" ]]; then
    exit 0
fi

if ! cli="$(sandpiper_tasks_bin)"; then
    block_with_reason "sandpiper-tasks CLI not found"
fi

if ! project_root="$(find_sandpiper_root "${cwd}")"; then
    block_with_reason "no .sandpiper/tasks/ directory in scope from cwd=${cwd}"
fi

# Mirror the body to the sandpiper task. Use --desc which replaces the
# entire description.
out="$("${cli}" --dir "${project_root}" task update "${sandpiper_key}" --desc "${new_body}" 2>&1)" || {
    block_with_reason "task update --desc on ${sandpiper_key} failed: ${out}"
}

emit_hook_output "PreToolUse" "Mirrored body to sandpiper: ${sandpiper_key} description updated."
exit 0
