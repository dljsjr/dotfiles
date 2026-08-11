#!/usr/bin/env bash
# TaskCompleted hook — mirror harness Task completion to sandpiper-tasks
# by looking up the session-scoped mapping populated at TaskCreated time.
#
# If the task wasn't mirrored at creation (no marker), this is a no-op.

set -uo pipefail

source "$(dirname "$0")/lib.sh"

input="$(cat)"

session_id="$(jq -r '.session_id // "unknown"' <<<"${input}")"
task_id="$(jq -r '.task_id // empty' <<<"${input}")"
cwd="$(jq -r '.cwd // empty' <<<"${input}")"

# Look up the sandpiper key. If there's no mapping, this harness Task
# wasn't mirrored at creation — let it complete locally without any
# sandpiper interaction.
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

# Move sandpiper task to NEEDS REVIEW. Final close (--final --resolution
# DONE) stays manual on purpose — that's a meaningful workflow boundary.
out="$("${cli}" --dir "${project_root}" task complete "${sandpiper_key}" 2>&1)" || {
    block_with_reason "task complete ${sandpiper_key} failed: ${out}"
}

# Clean up the mapping.
mapping_file="$(session_mapping_file "${session_id}")"
if [[ -f "${mapping_file}" ]]; then
    tmp="${mapping_file}.tmp.$$"
    jq --arg k "${task_id}" 'del(.[$k])' < "${mapping_file}" > "${tmp}" 2>/dev/null && mv "${tmp}" "${mapping_file}"
    # If the mapping file is now empty `{}`, delete it.
    if [[ "$(cat "${mapping_file}")" == "{}" ]]; then
        rm -f "${mapping_file}"
    fi
fi

emit_hook_output "TaskCompleted" "Mirrored to sandpiper: ${sandpiper_key} → NEEDS REVIEW. Final close (DONE / WONTFIX) stays manual."
exit 0
