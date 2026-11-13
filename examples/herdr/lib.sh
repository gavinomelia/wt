# Shared by the herdr scripts and subcommands. Needs herdr (https://herdr.dev) and jq.
AGENT=${WT_AGENT:-claude}
EDITOR_COMMAND=${WT_EDITOR_COMMAND:-${EDITOR:-nvim}}
REVIEW_PROMPT=${WT_REVIEW_PROMPT:-'Review this branch against %s: the committed diff from the merge base plus any uncommitted changes. Another agent wrote it. Apply AGENTS.md and any docs/conventions files that match the changed paths. Do not edit files; running targeted specs is fine. Report findings ranked by severity, each with file:line, the failing scenario, and a suggested fix. If nothing is worth fixing, say so plainly.'}

die() { echo "wt: $*" >&2; exit 1; }

# The workspace herdr has open on a checkout, if any
workspace_for_path() {
  herdr worktree list --cwd "$WT_MAIN" |
    jq -r --arg p "$1" '.result.worktrees[] | select(.path == $p) | .open_workspace_id // empty'
}

# The agent left (70%), the editor right (30%), a terminal along the bottom (15%)
dev_layout() {
  local ai_pane=$1 dir=$2 name=$3 editor_pane
  shift 3
  herdr pane split "$ai_pane" --direction down --ratio 0.85 --cwd "$dir" --no-focus >/dev/null
  editor_pane=$(herdr pane split "$ai_pane" --direction right --ratio 0.7 --cwd "$dir" --no-focus |
    jq -r '.result.pane.pane_id')
  herdr pane run "$editor_pane" "$EDITOR_COMMAND" >/dev/null
  start_agent "$name" "$AGENT" "$ai_pane" "$@"
}

# Returns agent_not_ready while the agent asks whether to trust the new folder; that's expected
start_agent() {
  local name=$1 kind=$2 pane=$3
  shift 3
  local args=("$@")
  [ "$kind" = claude ] && args=(--permission-mode auto "${args[@]}")
  herdr agent start "$name" --kind "$kind" --pane "$pane" -- "${args[@]}" >/dev/null 2>&1 || true
}

# Claude keeps a checkout's conversations under its path with every other character turned into
# "-", so a checkout that had one picks up where it left off
resume_args() {
  local sessions=${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects/${1//[^A-Za-z0-9]/-}
  [ "$AGENT" = claude ] && compgen -G "$sessions/*.jsonl" >/dev/null && echo --continue
  return 0
}

branch_name() { git -C "$1" branch --show-current 2>/dev/null || true; }
