#!/usr/bin/env bash
# Shared helpers for claude-stasks hooks.
#
# Convention: each hook script reads JSON from stdin, sources this lib, and
# uses the helpers below to find sandpiper-tasks, parse markers, and emit
# structured hook output.

set -uo pipefail

# Where to find the sandpiper-tasks CLI. Override via SANDPIPER_TASKS_BIN.
sandpiper_tasks_bin() {
    if [[ -n "${SANDPIPER_TASKS_BIN:-}" && -x "${SANDPIPER_TASKS_BIN}" ]]; then
        printf '%s\n' "${SANDPIPER_TASKS_BIN}"
        return 0
    fi
    if command -v sandpiper-tasks >/dev/null 2>&1; then
        command -v sandpiper-tasks
        return 0
    fi
    local default="${HOME}/.claude/skills/tasks/scripts/sandpiper-tasks"
    if [[ -x "${default}" ]]; then
        printf '%s\n' "${default}"
        return 0
    fi
    return 1
}

# Find the nearest .sandpiper/tasks/ directory walking upward from $1.
# Echoes the project root (the parent of .sandpiper/) on success. Returns
# 1 if no sandpiper-tasks workspace is in scope.
find_sandpiper_root() {
    local dir="${1:-$PWD}"
    while [[ "${dir}" != "/" && -n "${dir}" ]]; do
        if [[ -d "${dir}/.sandpiper/tasks" ]]; then
            printf '%s\n' "${dir}"
            return 0
        fi
        dir="$(dirname "${dir}")"
    done
    return 1
}

# Parse a sandpiper task marker out of a string. Echoes the marker
# canonical form on success, prints nothing and returns 1 if no marker is
# present. The marker forms recognized:
#
#   [PCCP-12]                 — existing task, will pickup
#   [+PCCP]                   — new task in project PCCP
#   [+sub PCCP-12]            — new subtask under PCCP-12
#
# Echoes a tab-separated `kind\tprojectkey\tparentkey` line:
#   pickup   PCCP-12     ""
#   create   PCCP        ""
#   subtask  PCCP        PCCP-12
parse_marker() {
    local input="${1:-}"

    # [+sub PCCP-N]
    if [[ "${input}" =~ \[\+sub[[:space:]]+([A-Z][A-Z0-9_-]*)-([0-9]+)\] ]]; then
        local proj="${BASH_REMATCH[1]}"
        local n="${BASH_REMATCH[2]}"
        printf 'subtask\t%s\t%s-%s\n' "${proj}" "${proj}" "${n}"
        return 0
    fi

    # [+PROJECTKEY]
    if [[ "${input}" =~ \[\+([A-Z][A-Z0-9_-]*)\] ]]; then
        printf 'create\t%s\t\n' "${BASH_REMATCH[1]}"
        return 0
    fi

    # [PROJECTKEY-N]
    if [[ "${input}" =~ \[([A-Z][A-Z0-9_-]*-[0-9]+)\] ]]; then
        local key="${BASH_REMATCH[1]}"
        local proj="${key%-*}"
        printf 'pickup\t%s\t\n' "${key}"
        return 0
    fi

    return 1
}

# Strip the marker from a string (returns the rest, trimmed).
strip_marker() {
    local input="${1:-}"
    # Remove any [PCCP-N], [+PCCP], or [+sub PCCP-N] form.
    local stripped
    stripped="$(printf '%s' "${input}" | sed -E 's/\[\+sub[[:space:]]+[A-Z][A-Z0-9_-]*-[0-9]+\]//; s/\[\+[A-Z][A-Z0-9_-]*\]//; s/\[[A-Z][A-Z0-9_-]*-[0-9]+\]//')"
    # Trim leading/trailing whitespace.
    printf '%s' "${stripped}" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//'
}

# Path to the per-session mapping file (task_id → sandpiper key).
session_mapping_file() {
    local session_id="${1:-unknown}"
    local dir="${HOME}/.claude/hooks/claude-stasks/data/sessions"
    mkdir -p "${dir}" 2>/dev/null
    printf '%s/%s.json\n' "${dir}" "${session_id}"
}

# Look up the sandpiper key associated with a task_id in the current
# session. Echoes the key on hit, returns 1 on miss.
mapping_get() {
    local session_id="$1" task_id="$2"
    local file
    file="$(session_mapping_file "${session_id}")"
    [[ -f "${file}" ]] || return 1
    jq -e -r --arg k "${task_id}" '.[$k] // empty' < "${file}" 2>/dev/null
}

# Set the mapping. Creates the file if missing. Atomic-ish via temp+rename.
mapping_put() {
    local session_id="$1" task_id="$2" sandpiper_key="$3"
    local file tmp
    file="$(session_mapping_file "${session_id}")"
    tmp="${file}.tmp.$$"
    if [[ -f "${file}" ]]; then
        jq --arg k "${task_id}" --arg v "${sandpiper_key}" '. + {($k): $v}' < "${file}" > "${tmp}" 2>/dev/null
    else
        jq -n --arg k "${task_id}" --arg v "${sandpiper_key}" '{($k): $v}' > "${tmp}" 2>/dev/null
    fi
    if [[ -s "${tmp}" ]]; then
        mv "${tmp}" "${file}"
    else
        rm -f "${tmp}"
        return 1
    fi
}

# Emit a JSON hook output block.
emit_hook_output() {
    local event_name="$1" context="$2"
    jq -nc --arg e "${event_name}" --arg c "${context}" '{
        hookSpecificOutput: {
            hookEventName: $e,
            additionalContext: $c
        }
    }'
}

# Block the hook with stderr explanation and exit 2.
block_with_reason() {
    local reason="$1"
    printf 'claude-stasks: %s\n' "${reason}" >&2
    exit 2
}
