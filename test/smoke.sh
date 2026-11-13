#!/usr/bin/env bash
# Smoke test: runs wt against a throwaway repo with a local remote and stub hooks.
# Needs only bash and git. Run with `npm test`.
set -euo pipefail

WT=$(cd "$(dirname "$0")/.." && pwd)/bin/wt
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
unset "${!WT_@}" HERDR_PANE_ID HC_TERMINAL_ID TMUX 2>/dev/null || true
export WT_CONFIG_DIR=$tmp/config HOME=$tmp GIT_CONFIG_GLOBAL=$tmp/gitconfig
git config --global user.name test
git config --global user.email test@example.com
git config --global init.defaultBranch main

pass=0
fail() { echo "FAIL: $*" >&2; exit 1; }
ok() { pass=$((pass + 1)); }
expect() { # expect <description> <needle> <haystack>
  case $3 in *"$2"*) ok ;; *) fail "$1: expected '$2' in: $3" ;; esac
}

git init -q --bare "$tmp/remote.git"
git clone -q "$tmp/remote.git" "$tmp/app" 2>/dev/null
cd "$tmp/app"
git commit -q --allow-empty -m init
git push -q origin main
git remote set-head origin -a >/dev/null

# No settings: a worktree beside the repo, and its path
out=$("$WT" new feature/one)
[ "$out" = "$tmp/worktrees/app/feature-one" ] || fail "new without hooks printed $out"; ok
[ "$("$WT" path feature/one)" = "$tmp/worktrees/app/feature-one" ] || fail "path"; ok
[ "$("$WT" new feature/one)" = "$tmp/worktrees/app/feature-one" ] || fail "reopening"; ok
expect "ls" "feature/one" "$("$WT" ls 2>/dev/null)"

# Hooks
mkdir -p "$WT_CONFIG_DIR/projects" "$WT_CONFIG_DIR/commands"
cat >"$WT_CONFIG_DIR/projects/app.env" <<'EOF'
WT_TICKET_PREFIX=abc
WT_TICKET_BRANCH='echo "$(echo "$WT_TICKET" | tr A-Z a-z)-fix-the-thing"'
WT_TICKET_PROMPT='Read %s'
WT_ON_OPEN='echo "open created=$WT_CREATED branch=$WT_BRANCH name=$WT_NAME label=$WT_LABEL prompt=$WT_PROMPT custom=$WT_CUSTOM"'
WT_ON_SETUP='echo "setup $PWD" >>"$HOME/setup.log"'
WT_SERVE='echo "serve $PWD $*"'
WT_URL='echo "https://$WT_BRANCH.test"'
WT_ON_REMOVE='echo "remove $WT_BRANCH"'
WT_ON_GC='echo "gc dry=$WT_DRY_RUN"'
WT_CUSTOM=from-settings
EOF
printf '#!/bin/sh\necho "hello $WT_REPO $*"\n' >"$WT_CONFIG_DIR/commands/wt-hello"
chmod +x "$WT_CONFIG_DIR/commands/wt-hello"

out=$("$WT" new ABC-12)
expect "ticket open" "open created=1 branch=abc-12-fix-the-thing name=abc-12 label=fix the thing prompt=Read ABC-12 custom=from-settings" "$out"
out=$("$WT" new abc-12-fix-the-thing)
expect "reopen" "created=0" "$out"
out=$(WT_CUSTOM=from-env "$WT" new abc-12-fix-the-thing)
expect "environment beats settings" "custom=from-env" "$out"

cd "$tmp/worktrees/app/abc-12-fix-the-thing"
expect "serve sets up first" "serve $PWD -p 1" "$("$WT" serve -p 1)"
"$WT" serve >/dev/null
[ "$(grep -c setup "$HOME/setup.log")" = 1 ] || fail "setup ran more than once"; ok
expect "url" "https://abc-12-fix-the-thing.test" "$("$WT" url)"
cd "$tmp/app"

expect "commands" "hello app a b" "$("$WT" hello a b)"
expect "gc dry run" "gc dry=1" "$("$WT" gc --dry-run)"

touch "$tmp/worktrees/app/abc-12-fix-the-thing/dirty"
"$WT" rm abc-12-fix-the-thing 2>/dev/null && fail "rm removed a dirty worktree"; ok
out=$("$WT" rm --force abc-12-fix-the-thing)
expect "rm runs on-remove" "remove abc-12-fix-the-thing" "$out"
expect "rm runs gc" "gc dry=" "$out"
[ ! -e "$tmp/worktrees/app/abc-12-fix-the-thing" ] || fail "rm left the worktree"; ok
git show-ref --verify --quiet refs/heads/abc-12-fix-the-thing || fail "rm deleted the branch"; ok

# Outside a repo, WT_MAIN picks the project
echo "WT_MAIN=$tmp/app" >"$WT_CONFIG_DIR/config"
cd "$tmp"
[ "$("$WT" path)" = "$tmp/app" ] || fail "WT_MAIN outside a repo"; ok
rm "$WT_CONFIG_DIR/config"
"$WT" path 2>/dev/null && fail "path outside a repo without WT_MAIN"; ok

# wt init with every default: Rails on PostgreSQL, no ticket key, nowhere to open
git init -q "$tmp/shop_app"
cd "$tmp/shop_app"
mkdir config
printf 'development:\n  database: shop_development\n' >config/database.yml
out=$("$WT" init --yes)
expect "init writes settings" "Wrote $WT_CONFIG_DIR/projects/shop_app.env" "$out"
expect "init lists requirements" ".env_overrides.rb" "$out"
settings=$(cat "$WT_CONFIG_DIR/projects/shop_app.env")
expect "init reads the database prefix" "WT_DB_PREFIX=shop" "$settings"
[ -x "$WT_CONFIG_DIR/rails-postgres/setup" ] || fail "init didn't copy the rails-postgres scripts"; ok
expect "init settings load" "rails-postgres/serve" "$("$WT" config)"
expect "init keeps existing settings" "Kept" "$("$WT" init --yes)"

echo "ok: $pass checks"
