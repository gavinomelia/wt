# Shared by the Herdr.app hooks and commands. Drives Herdr.app on macOS through `herdr-app do`, and
# uses python3 (from the Xcode command line tools) to read its JSON.
AGENT=${WT_AGENT:-claude}
REVIEW_PROMPT=${WT_REVIEW_PROMPT:-'Review this branch against %s: the committed diff from the merge base plus any uncommitted changes. Another agent wrote it. Apply AGENTS.md and any docs/conventions files that match the changed paths. Do not edit files; running targeted specs is fine. Report findings ranked by severity, each with file:line, the failing scenario, and a suggested fix. If nothing is worth fixing, say so plainly.'}

die() { echo "wt: $*" >&2; exit 1; }

herdr_running() { command -v herdr-app >/dev/null 2>&1 && herdr-app ls >/dev/null 2>&1; }

json_array() { python3 -c 'import json, sys; print(json.dumps(sys.argv[1:]))' "$@"; }
json_field() { python3 -c 'import json, sys; print(json.load(sys.stdin).get(sys.argv[1]) or "")' "$1"; }

# terminal<TAB>pane<TAB>space<TAB>folder<TAB>tab for every terminal Herdr has open
herdr_panes() {
  herdr-app ls | python3 -c '
import json, sys
for space in json.load(sys.stdin)["spaces"]:
    for tab in space["tabs"]:
        for t in tab["terminals"]:
            print(t["terminal"], t["pane"], space["id"], space["folder"], tab["id"], sep="\t")'
}
tab_of_terminal() { herdr_panes | awk -F'\t' -v t="$1" '$1 == t { print $5; exit }'; }
pane_of_terminal() { herdr_panes | awk -F'\t' -v t="$1" '$1 == t { print $2; exit }'; }
spaces_in_folder() { herdr_panes | awk -F'\t' -v f="$1" '$4 == f { print $3 }' | sort -u; }

# The agent's argv as JSON; extra args go to Claude (a first message, --continue)
agent_argv() {
  local name=$1
  shift
  case $AGENT in
    claude) json_array claude --permission-mode auto --name "$name" "$@" ;;
    *) json_array "$AGENT" "$@" ;;
  esac
}

# Claude keeps a checkout's conversations under its path with every other character turned into
# "-", so a checkout that had one picks up where it left off
resume_flag() {
  local sessions=${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects/$(echo "$1" | sed 's/[^A-Za-z0-9]/-/g')
  [ "$AGENT" = claude ] && compgen -G "$sessions/*.jsonl" >/dev/null && echo --continue
  return 0
}

# The agent on the left, a shell on the right, and WT_EDITOR_COMMAND (if set) under the agent
code_layout() {
  local pane=$1
  herdr-app do pane.split --direction right --pane "$pane" >/dev/null
  [ -z "${WT_EDITOR_COMMAND:-}" ] ||
    herdr-app do pane.split --direction down --pane "$pane" --argv "$(json_array sh -c "$WT_EDITOR_COMMAND")" >/dev/null
  herdr-app do pane.focus --pane "$pane" >/dev/null
}

# A space with a "code" tab, plus a "server" tab running $4 when it's set. $5 is the agent's first message.
open_space() {
  local name=$1 folder=$2 argv=$3 server=${4:-} task=${5:-} made space tab
  if [ -n "$task" ]; then
    made=$(herdr-app do space.new --name "$name" --folder "$folder" --tab code --argv "$argv" --task "$task")
  else
    made=$(herdr-app do space.new --name "$name" --folder "$folder" --tab code --argv "$argv")
  fi
  space=$(echo "$made" | json_field space)
  tab=$(echo "$made" | json_field tab)
  code_layout "$(pane_of_terminal "$(echo "$made" | json_field terminal)")"
  if [ -n "$server" ]; then
    herdr-app do tab.new --name server --space "$space" --folder "$folder" \
      --argv "$(json_array sh -c "$server")" >/dev/null
    herdr-app do tab.select --id "$tab" >/dev/null
  fi
}

branch_name() { git -C "$1" symbolic-ref --quiet --short HEAD 2>/dev/null || true; }
