#!/usr/bin/env bash
# PreToolUse hook on EnterPlanMode — surface the existing planning
# trinity (Spec + Decisions + Work Plan) and any other artifacts in
# .sandpiper/docs/ as context, so plan output can be informed by and
# consistent with the project's documented design.
#
# The convention this hook recognizes (PRD + Spec + Work Plan trinity):
#   *-prd.md          — product requirements: motivations, goals, constraints,
#                       and a decision log section. Why we're doing this and
#                       why the design looks the way it does.
#   *-spec.md         — what we're building (architecture, surface, contracts)
#   *-work-plan.md    — how we'll build it (phases, gates, estimates, risks)
#   HANDOFF.md        — current orientation / where to start
#
# Legacy variant: *-decisions.md is a broken-out form of what would
# normally be the decision log inside the PRD. Surfaced under the PRD
# category for projects where the design conversation was elsewhere.

set -uo pipefail

source "$(dirname "$0")/lib.sh"

input="$(cat)"

tool_name="$(jq -r '.tool_name // empty' <<<"${input}")"
if [[ "${tool_name}" != "EnterPlanMode" ]]; then
    exit 0
fi

cwd="$(jq -r '.cwd // empty' <<<"${input}")"

if ! project_root="$(find_sandpiper_root "${cwd}")"; then
    exit 0
fi

docs_dir="${project_root}/.sandpiper/docs"
if [[ ! -d "${docs_dir}" ]]; then
    exit 0
fi

# Helper: list files matching any of the given globs that actually
# exist. Globs that match nothing are skipped silently.
find_existing() {
    local result=()
    local pattern f
    for pattern in "$@"; do
        # Expand the glob; bash 3.2 leaves it literal on no match, so
        # check existence before adding.
        for f in ${pattern}; do
            if [[ -f "${f}" ]]; then
                result+=("${f}")
            fi
        done
    done
    if [[ ${#result[@]} -gt 0 ]]; then
        printf '%s\n' "${result[@]}"
    fi
}

# Single canonical pattern per category. Filesystem case-sensitivity
# would let us match multiple variants but on macOS that produces
# duplicate entries that all resolve to the same file. Keep it simple.
handoffs="$(find_existing "${docs_dir}/HANDOFF.md")"
# PRD (canonical) plus the legacy *-decisions.md variant.
prds="$(find_existing "${docs_dir}"/*-prd.md "${docs_dir}/prd.md" "${docs_dir}/PRD.md" "${docs_dir}"/*-decisions.md "${docs_dir}/decisions.md")"
specs="$(find_existing "${docs_dir}"/*-spec.md "${docs_dir}/spec.md")"
work_plans="$(find_existing "${docs_dir}"/*-work-plan.md "${docs_dir}/work-plan.md")"

# All other .md files in docs_dir not in the trinity above.
trinity_paths="$(printf '%s\n%s\n%s\n%s\n' "${handoffs}" "${prds}" "${specs}" "${work_plans}" | grep -v '^$' || true)"

others=""
for f in "${docs_dir}"/*.md; do
    [[ -f "${f}" ]] || continue
    if ! printf '%s\n' "${trinity_paths}" | grep -qxF "${f}"; then
        others+="${f}"$'\n'
    fi
done
others="$(printf '%s' "${others}" | grep -v '^$' || true)"

# If everything's empty, no-op.
if [[ -z "${handoffs}${prds}${specs}${work_plans}${others}" ]]; then
    exit 0
fi

# Build the additionalContext block.
ctx="Project planning context (\`.sandpiper/docs/\` in ${project_root}):"

append_section() {
    local label="$1" body="$2"
    [[ -z "${body}" ]] && return
    ctx="${ctx}

**${label}**"
    while IFS= read -r path; do
        [[ -z "${path}" ]] && continue
        ctx="${ctx}
  - ${path}"
    done <<< "${body}"
}

append_section "Orientation (read first if unfamiliar with the project)" "${handoffs}"
append_section "PRD (motivations, goals, constraints, decision log)" "${prds}"
append_section "Spec (what we're building — architecture, surfaces, contracts)" "${specs}"
append_section "Work Plan (how we'll build it — phases, gates, estimates)" "${work_plans}"
append_section "Other artifacts (verification notes, investigations, amendments)" "${others}"

ctx="${ctx}

This project follows the **PRD / Spec / Work Plan** trinity convention. When planning new work:

  1. Read the existing artifacts above before drafting your plan — your plan should be consistent with them or explicitly amend them.
  2. Structure your plan to fit the convention: motivation (PRD-flavored why + decision-log entry), what changes (Spec-flavored), how (Work Plan-flavored phases / steps), and what stays.
  3. If your plan introduces non-trivial new direction, propose a corresponding doc artifact: a new decision-log entry inside the PRD for rationale, a Spec amendment, a phase amendment to the Work Plan, or a focused investigation doc (\`-hook-dispatch.md\` / \`-blocking-mcp.md\` are good examples already in this project).
  4. If the plan itself is durable (architectural sketch, multi-session implementation guide), tag it \`[persist as: <slug>]\` so the ExitPlanMode hook saves it under \`.sandpiper/docs/plans/\`."

emit_hook_output "PreToolUse" "${ctx}"
exit 0
