#!/usr/bin/env bash
# TaskCreated hook — mirror harness Task creation to sandpiper-tasks if
# the task title contains a recognized marker.
#
# Marker forms:
#   [PCCP-12]                 — pickup existing task (move to IN_PROGRESS)
#   [+PCCP]                   — create new top-level task in project PCCP
#   [+sub PCCP-12]            — create new subtask under PCCP-12
#
# No marker → no-op, return 0 (let the harness Task be ephemeral).

set -uo pipefail

source "$(dirname "$0")/lib.sh"

input="$(cat)"

session_id="$(jq -r '.session_id // "unknown"' <<<"${input}")"
task_id="$(jq -r '.task_id // empty' <<<"${input}")"
cwd="$(jq -r '.cwd // empty' <<<"${input}")"

# The task input fields aren't fully stable across CC versions. Current
# CC (2.1.x, 2026-07) sends flat top-level `task_subject`/`task_description`;
# older versions nested under `task_input`/`tool_input`. Try known fields
# newest-first, then fall back to scanning all string values for a marker.
title="$(jq -r '
    .task_subject //
    .task_input.subject //
    .task_input.title //
    .task_input.description //
    .task_input.activeForm //
    .tool_input.subject //
    .tool_input.title //
    .tool_input.description //
    .tool_input.activeForm //
    .task_description //
    empty
' <<<"${input}")"

if [[ -z "${title}" ]]; then
    # Scan every string field of the whole payload for a marker (minus
    # infrastructure fields that could never carry one but add noise).
    title="$(jq -r '
        [del(.transcript_path, .cwd, .session_id, .prompt_id, .hook_event_name, .task_id)
         | .. | strings] | join(" ")
    ' <<<"${input}")"
fi

# Find a marker.
marker_line="$(parse_marker "${title}" || true)"
if [[ -z "${marker_line}" ]]; then
    # No marker → no mirroring. Pass through.
    exit 0
fi

IFS=$'\t' read -r kind project_key parent_key <<<"${marker_line}"

# Locate sandpiper-tasks CLI.
if ! cli="$(sandpiper_tasks_bin)"; then
    block_with_reason "sandpiper-tasks CLI not found (set SANDPIPER_TASKS_BIN or install)"
fi

# Locate the project root.
if ! project_root="$(find_sandpiper_root "${cwd}")"; then
    block_with_reason "no .sandpiper/tasks/ directory in scope from cwd=${cwd}"
fi

case "${kind}" in
    pickup)
        # project_key is the full task key (PCCP-12); pickup directly.
        out="$("${cli}" --dir "${project_root}" task pickup "${project_key}" 2>&1)" || {
            block_with_reason "task pickup ${project_key} failed: ${out}"
        }
        # Stash the mapping for TaskCompleted later.
        mapping_put "${session_id}" "${task_id}" "${project_key}" || true
        emit_hook_output "TaskCreated" "Mirrored to sandpiper: picked up ${project_key} (now IN PROGRESS)."
        exit 0
        ;;
    create)
        # project_key is the project (PCCP); create a new top-level task.
        clean_title="$(strip_marker "${title}")"
        # The CLI doesn't take --desc on create (known issue); pass via title only for MVP.
        out="$("${cli}" --dir "${project_root}" task create -p "${project_key}" -t "${clean_title}" --reporter AGENT 2>&1)" || {
            block_with_reason "task create -p ${project_key} failed: ${out}"
        }
        # Parse the assigned key from output: "Created PCCP-14: <title>"
        new_key="$(printf '%s' "${out}" | grep -oE '[A-Z][A-Z0-9_-]*-[0-9]+' | head -1 || true)"
        if [[ -z "${new_key}" ]]; then
            block_with_reason "task create succeeded but couldn't parse assigned key from output: ${out}"
        fi
        # Move it to IN_PROGRESS to match the harness Task lifecycle.
        "${cli}" --dir "${project_root}" task pickup "${new_key}" >/dev/null 2>&1 || true
        mapping_put "${session_id}" "${task_id}" "${new_key}" || true

        # The harness's TaskCreated event is post-hoc notification — there
        # is no reliable input-rewrite surface to rename the harness task
        # from here. Instruct the agent to do the rename itself so the
        # canonical key is embedded for subsequent operations.
        new_title="[${new_key}] ${clean_title}"
        emit_hook_output "TaskCreated" "Mirrored to sandpiper: created ${new_key} (now IN PROGRESS). ACTION REQUIRED: update this harness task's subject to \"${new_title}\" via TaskUpdate(taskId: ${task_id}) so the canonical key is embedded."
        exit 0
        ;;
    subtask)
        # parent_key is the parent task (PCCP-12).
        clean_title="$(strip_marker "${title}")"
        out="$("${cli}" --dir "${project_root}" task create -p "${project_key}" -t "${clean_title}" -k SUBTASK --parent "${parent_key}" --reporter AGENT 2>&1)" || {
            block_with_reason "subtask create under ${parent_key} failed: ${out}"
        }
        new_key="$(printf '%s' "${out}" | grep -oE '[A-Z][A-Z0-9_-]*-[0-9]+' | head -1 || true)"
        if [[ -z "${new_key}" ]]; then
            block_with_reason "subtask create succeeded but couldn't parse assigned key: ${out}"
        fi
        "${cli}" --dir "${project_root}" task pickup "${new_key}" >/dev/null 2>&1 || true
        mapping_put "${session_id}" "${task_id}" "${new_key}" || true
        emit_hook_output "TaskCreated" "Mirrored to sandpiper: created subtask ${new_key} under ${parent_key} (now IN PROGRESS)."
        exit 0
        ;;
esac

# Unreachable.
exit 0
