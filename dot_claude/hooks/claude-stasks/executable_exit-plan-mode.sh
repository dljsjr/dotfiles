#!/usr/bin/env bash
# PreToolUse hook for ExitPlanMode — persist the plan as a doc artifact
# IF the plan text contains a `[persist as: filename]` marker. Default
# is no-op (plans stay ephemeral session reasoning).
#
# Marker form: [persist as: <slug>]   →  saved to
# <project_root>/.sandpiper/docs/plans/YYYY-MM-DD-<slug>.md

set -uo pipefail

source "$(dirname "$0")/lib.sh"

input="$(cat)"

# Confirm this is an ExitPlanMode call. PreToolUse fires for every tool
# with a matcher, but we install with `matcher: "ExitPlanMode"` so this
# is mostly defensive.
tool_name="$(jq -r '.tool_name // empty' <<<"${input}")"
if [[ "${tool_name}" != "ExitPlanMode" ]]; then
    exit 0
fi

cwd="$(jq -r '.cwd // empty' <<<"${input}")"
plan="$(jq -r '.tool_input.plan // empty' <<<"${input}")"

# Look for the persistence marker.
if [[ ! "${plan}" =~ \[persist[[:space:]]+as:[[:space:]]*([a-zA-Z0-9_-]+)\] ]]; then
    # No marker → ephemeral plan. Pass through.
    exit 0
fi

slug="${BASH_REMATCH[1]}"

if ! project_root="$(find_sandpiper_root "${cwd}")"; then
    block_with_reason "[persist as: ${slug}] requested but no .sandpiper/tasks/ in scope from cwd=${cwd}"
fi

plans_dir="${project_root}/.sandpiper/docs/plans"
mkdir -p "${plans_dir}" || block_with_reason "failed to mkdir ${plans_dir}"

date_prefix="$(date +%Y-%m-%d)"
filename="${plans_dir}/${date_prefix}-${slug}.md"

# Strip the persist marker from the plan body before writing.
clean_plan="$(printf '%s' "${plan}" | sed -E 's/\[persist[[:space:]]+as:[[:space:]]*[a-zA-Z0-9_-]+\]//')"

# Write the plan with a small frontmatter block.
{
    printf -- '---\n'
    printf 'title: %s\n' "${slug}"
    printf 'created: %s\n' "$(date -Iseconds)"
    printf 'kind: plan\n'
    printf -- '---\n\n'
    printf '# %s\n\n' "${slug}"
    printf '%s\n' "${clean_plan}"
} > "${filename}" || block_with_reason "failed to write ${filename}"

emit_hook_output "PreToolUse" "Plan persisted to ${filename}. The plan was also passed through to ExitPlanMode unchanged (minus the [persist as] marker)."
exit 0
