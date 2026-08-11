#!/usr/bin/env bash
# Custom Claude Code statusLine.
# Reads CC's session JSON from stdin, emits a 2-line status.
#
# Line 1: <model> · <effort>  ❯  ⏳ 5hr <bar> NN% · resets <Xh Ym>  ❯  ◷ 7d <bar> NN% · resets <Xd>
# Line 2: <cwd>[ (worktree: <name>)]  ❯  <vcs-info>
#
# Section separator: ❯ (dim chevron). In-section separator: · (middle dot).
# Effort is colored by level. Bars colored by utilization (green/yellow/red).
# VCS walks up from cwd looking for .jj/ then .git/. jj wins in colocated repos.

set -uo pipefail

input=$(cat)

jqr() { jq -r "$1" 2>/dev/null <<<"$input"; }

cwd=$(jqr '.cwd // .workspace.current_dir // ""')
model=$(jqr '.model.display_name // .model.id // "?"')
effort=$(jqr '.effort.level // ""')

ctx_pct=$(jqr '.context_window.used_percentage // ""')
ctx_size=$(jqr '.context_window.context_window_size // ""')

five_pct=$(jqr '.rate_limits.five_hour.used_percentage // ""')
five_reset=$(jqr '.rate_limits.five_hour.resets_at // ""')
week_pct=$(jqr '.rate_limits.seven_day.used_percentage // ""')
week_reset=$(jqr '.rate_limits.seven_day.resets_at // ""')

git_worktree=$(jqr '.workspace.git_worktree // ""')
session_worktree_name=$(jqr '.worktree.name // ""')

human_duration() {
    local secs=$1
    (( secs < 0 )) && secs=0
    if (( secs < 60 )); then
        printf '%ds' "$secs"
    elif (( secs < 3600 )); then
        printf '%dm' $(( secs / 60 ))
    elif (( secs < 86400 )); then
        local h=$(( secs / 3600 )) m=$(( (secs % 3600) / 60 ))
        if (( m == 0 )); then printf '%dh' "$h"; else printf '%dh %dm' "$h" "$m"; fi
    else
        local d=$(( secs / 86400 )) h=$(( (secs % 86400) / 3600 ))
        if (( h == 0 )); then printf '%dd' "$d"; else printf '%dd %dh' "$d" "$h"; fi
    fi
}

context_size_label() {
    local size=$1
    if (( size >= 1000000 )); then printf '%dM'  $(( size / 1000000 ))
    elif (( size >= 1000 ));    then printf '%dK' $(( size / 1000 ))
    else printf '%d' "$size"
    fi
}

# Auto-compaction is on unless DISABLE_COMPACT or DISABLE_AUTO_COMPACT are
# truthy (per CC's r0() at 4068.js:167-171).
compaction_mode() {
    local v low
    for v in "${DISABLE_COMPACT:-}" "${DISABLE_AUTO_COMPACT:-}"; do
        low=$(printf '%s' "$v" | tr '[:upper:]' '[:lower:]')
        case "$low" in
            1|true|yes|on) printf 'manual'; return ;;
        esac
    done
    printf 'auto'
}

# Match CC's own /effort picker palette (4694.js:31-35 → 2205.js ANSI variant).
# low=warning(yellow), medium=success(green), high=permission(blue),
# xhigh=autoAccept(magenta), max=rainbow-animated (no static; using bold bright red).
effort_color() {
    case "$1" in
        low)    printf '\033[33m'   ;;  # yellow   (warning)
        medium) printf '\033[32m'   ;;  # green    (success)
        high)   printf '\033[34m'   ;;  # blue     (permission)
        xhigh)  printf '\033[35m'   ;;  # magenta  (autoAccept)
        max)    printf '\033[1;91m' ;;  # bold bright red — stand-in for rainbow-animated
        *)      printf '\033[37m'   ;;  # white fallback
    esac
}

bar() {
    local pct_int=$1
    (( pct_int < 0 )) && pct_int=0
    (( pct_int > 100 )) && pct_int=100
    local fill=$(( pct_int / 10 ))
    local empty=$(( 10 - fill ))
    local color
    if (( pct_int < 50 )); then color=$'\033[32m'
    elif (( pct_int < 80 )); then color=$'\033[33m'
    else color=$'\033[31m'
    fi
    local filled="" unfilled=""
    for ((i=0; i<fill;  i++)); do filled+="█"; done
    for ((i=0; i<empty; i++)); do unfilled+="░"; done
    printf '%s%s\033[2m%s\033[0m' "$color" "$filled" "$unfilled"
}

display_cwd() {
    local p=$1
    [[ -n "$HOME" && "$p" == "$HOME"* ]] && p="~${p#$HOME}"
    printf '%s' "$p"
}

find_repo_root() {
    local d=$1 kind
    while [[ -n "$d" && "$d" != "/" ]]; do
        if   [[ -d "$d/.jj"  ]]; then printf 'jj %s'  "$d"; return; fi
        if   [[ -e "$d/.git" ]]; then printf 'git %s' "$d"; return; fi
        d=$(dirname "$d")
    done
}

jj_status() {
    local repo=$1 raw change_id desc bookmarks conflict trunk_dist
    raw=$(JJ_CONFIG=/dev/null jj --repository "$repo" --ignore-working-copy log -r @ --no-graph --color=never -T '
        change_id.short() ++ "\n" ++
        coalesce(description.first_line(), "(no description)") ++ "\n" ++
        bookmarks.map(|b| b.name()).join(",") ++ "\n" ++
        if(conflict, "1", "0")
    ' 2>/dev/null) || return 0
    [[ -z "$raw" ]] && return 0
    change_id=$(sed -n '1p' <<<"$raw")
    desc=$(sed    -n '2p' <<<"$raw")
    bookmarks=$(sed -n '3p' <<<"$raw")
    conflict=$(sed -n '4p' <<<"$raw")

    if [[ ${#desc} -gt 36 ]]; then desc="${desc:0:35}…"; fi

    trunk_dist=$(JJ_CONFIG=/dev/null jj --repository "$repo" --ignore-working-copy log -r 'trunk()..@-' --no-graph --color=never -T '"x"' 2>/dev/null | tr -cd 'x' | wc -c | tr -d ' ')

    local extras=""
    [[ -n "$bookmarks" ]] && extras+=$' \033[32m'"$bookmarks"$'\033[0m'
    if [[ -n "$trunk_dist" && "$trunk_dist" -gt 0 ]]; then extras+=$' \033[36m+'"$trunk_dist"$'\033[0m'; fi
    [[ "$conflict" == "1" ]] && extras+=$' \033[1;31m⚠ conflict\033[0m'

    printf $'\033[35m◆\033[0m \033[33m%s\033[0m \033[2m"%s"\033[0m%s' "$change_id" "$desc" "$extras"
}

git_status_line() {
    local repo=$1 branch dirty
    branch=$(git -C "$repo" symbolic-ref --short HEAD 2>/dev/null \
          || git -C "$repo" rev-parse --short HEAD 2>/dev/null)
    [[ -z "$branch" ]] && return 0
    if [[ -n "$(git -C "$repo" status --porcelain 2>/dev/null)" ]]; then dirty="*"; else dirty=""; fi
    printf $'\033[34m⎇\033[0m \033[32m%s\033[0m\033[1;33m%s\033[0m' "$branch" "$dirty"
}

SEP=$'  \033[2m❯\033[0m  '   # dim chevron, major section break
DOT=$' \033[2m·\033[0m '     # dim middle dot, in-section break

cwd_display=$(display_cwd "$cwd")

vcs_segment=""
repo_info=$(find_repo_root "$cwd")
if [[ -n "$repo_info" ]]; then
    kind="${repo_info%% *}"
    root="${repo_info#* }"
    if [[ "$kind" == "jj" ]]; then
        v=$(jj_status "$root")
    else
        v=$(git_status_line "$root")
    fi
    [[ -n "$v" ]] && vcs_segment="${SEP}${v}"
fi

worktree_segment=""
if [[ -n "$session_worktree_name" ]]; then
    worktree_segment=$' \033[2m(worktree: '$session_worktree_name$')\033[0m'
elif [[ -n "$git_worktree" && "$git_worktree" != "null" ]]; then
    worktree_segment=$' \033[2m(worktree: '$git_worktree$')\033[0m'
fi

# Line 1: model + effort + rate limits
now=$(date +%s)
line1=$(printf $'\033[1;97m%s\033[0m' "$model")
if [[ -n "$effort" ]]; then
    ec=$(effort_color "$effort")
    line1+=$(printf '%s%s%s\033[0m' "$DOT" "$ec" "$effort")
fi
if [[ -n "$ctx_pct" ]]; then
    ctx_int=${ctx_pct%%.*}
    if [[ -n "$ctx_size" ]]; then size_label=$(context_size_label "$ctx_size"); else size_label="?"; fi
    cm=$(compaction_mode)
    line1+=$(printf $'%s\033[2m%d%% [%s] (%s)\033[0m' "$DOT" "$ctx_int" "$size_label" "$cm")
fi
if [[ -n "$five_pct" ]]; then
    five_int=${five_pct%%.*}
    b=$(bar "$five_int")
    line1+="${SEP}"
    if [[ -n "$five_reset" ]]; then
        d=$(human_duration $(( five_reset - now )))
        line1+=$(printf $'\033[33m⏳\033[0m \033[2;33m5hr\033[0m %s %2d%% \033[2m· resets %s\033[0m' "$b" "$five_int" "$d")
    else
        line1+=$(printf $'\033[33m⏳\033[0m \033[2;33m5hr\033[0m %s %2d%%' "$b" "$five_int")
    fi
fi
if [[ -n "$week_pct" ]]; then
    week_int=${week_pct%%.*}
    b=$(bar "$week_int")
    line1+="${SEP}"
    if [[ -n "$week_reset" ]]; then
        d=$(human_duration $(( week_reset - now )))
        line1+=$(printf $'\033[34m7d\033[0m %s %2d%% \033[2m· resets %s\033[0m' "$b" "$week_int" "$d")
    else
        line1+=$(printf $'\033[34m7d\033[0m %s %2d%%' "$b" "$week_int")
    fi
fi
printf '%s\n' "$line1"

# Line 2: cwd + vcs (📁 icon prefix on cwd)
printf $'\033[33m📁\033[0m \033[36m%s\033[0m%s%s\n' "$cwd_display" "$worktree_segment" "$vcs_segment"
