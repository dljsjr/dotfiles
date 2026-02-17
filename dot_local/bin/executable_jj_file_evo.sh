#!/usr/bin/env sh

REVSET='@'
FILESET='*'
while [ $# -gt 0 ]
do
    case "$1" in
        -r | --revset)
            REVSET="$2"
            shift
            ;;
        -f | --fileset)
            FILESET="$2"
            shift
            ;;
    esac
    shift
done

IFS= read -r -d '' JJ_EVOLOG_TEMPLATE <<-EOF
if(
    self.inter_diff("$FILESET").files().len() > 0 &&
    self.inter_diff("$FILESET").files().all(|diffentry|
        !(diffentry.source().conflict() || diffentry.target().conflict())
    ),
    commit.commit_id() ++ "\0",
    ""
)
EOF

jj log \
--no-graph --reversed --revisions \
"$(\
    jj evolog  --no-graph --revisions \
    "$REVSET & ~empty() & ~conflicts() & ~divergent() & diff_lines(\"*\", \"$FILESET\")" --template "$JJ_EVOLOG_TEMPLATE" |\
    xargs -0 printf "commit_id(%s) " |\
    xargs |\
    sed -e 's/ / | /g' \
)" \
--patch \
--template "builtin_log_oneline" \
--git \
"$FILESET"
