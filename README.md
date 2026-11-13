# wt

One git worktree per branch, so several coding agents can each work on their own branch of the same repo at once.

`wt` does the git part: it makes the worktree, finds the branch for a PR or ticket, reports which worktrees have merged, and cleans up. What happens around a worktree is up to your own hooks:

- where it opens (a herdr workspace, a tmux window, a Herdr.app space, or just a path);
- how it's set up (its own database, copied dependencies);
- how the app runs, and what's cleaned up after it.

`wt` doesn't depend on any terminal, agent, or framework.

```sh
wt new ABC-1234      # the Linear issue's branch, in its own worktree, with an agent reading the issue
wt new pr:1234       # a PR's branch, for review
wt ls                # every worktree with its PR, CI, uncommitted files, and distance from main
wt prune             # remove the worktrees whose PRs merged
```

## Install

```sh
npm install -g @gavinomelia/wt
```

It's a bash script, so it runs on Linux and macOS, including macOS's stock bash 3.2. It needs `git`. `gh` and `jq` add PRs: `wt new pr:1234`, plus the PR and CI columns and merge detection in `wt ls` and `wt prune`.

## Set it up with your agent

Point your coding agent at [configure.md](configure.md), say what you use, and it writes the hooks for you:

```sh
claude "Read https://github.com/gavinomelia/wt/blob/main/configure.md and configure herdr to work with wt"
```

`configure.md` is also installed with the package: `$(npm root -g)/@gavinomelia/wt/configure.md`.

## Or by hand

With no settings, `wt new feature-x` makes `../worktrees/<repo>/feature-x` beside your checkout, branched from an up-to-date `origin/main`, and prints its path. Everything else comes from settings files, which are bash files of `NAME=value` lines:

- `~/.config/wt/config` holds settings for every repo, such as your terminal's hooks.
- `~/.config/wt/projects/<repo>.env` holds one repo's settings, where `<repo>` is its main checkout's folder name.

`wt config` shows what's in effect where you are.

| Setting | What it's for |
|---|---|
| `WT_ON_OPEN` | Hook: open a worktree, new or existing, in your terminal or harness |
| `WT_ON_SETUP` | Hook: set up a new worktree (`wt setup`, and the first `wt serve`) |
| `WT_SERVE` | Hook: run the app (`wt serve`) |
| `WT_URL` | Hook: print the checkout's URL (`wt url`, `wt open`) |
| `WT_ON_REMOVE` | Hook: close what `WT_ON_OPEN` opened, before the worktree is removed |
| `WT_ON_GC` | Hook: clean up after worktrees that are gone, such as their databases |
| `WT_TICKET_PREFIX` | Your ticket key (`abc` for ABC-1234), so `wt new ABC-1234` works |
| `WT_TICKET_BRANCH` | Hook: print a ticket's branch name, from `WT_TICKET` |
| `WT_TICKET_PROMPT`, `WT_PR_PROMPT` | The agent's first message for a ticket or PR; `%s` is its ID |
| `WT_MAIN` | The repo to use when you run `wt` outside one, such as from a key binding |
| `WT_DIR` | Where worktrees go (default `<main checkout's parent>/worktrees/<repo>`) |
| `WT_BASE`, `WT_REMOTE` | The branch new worktrees start from (default the remote's default branch) and the remote (default `origin`) |
| `WT_IDLE_DAYS` | `wt prune` offers to remove a worktree with no PR after this many days without a commit (default 14) |
| `WT_COMMANDS` | Folders searched for `wt-<name>` commands, before `PATH` (default `~/.config/wt/commands`) |

### Hooks

A hook is a bash command, usually the path to a script. It gets its inputs as environment variables:

| Variable | Set for | Value |
|---|---|---|
| `WT_MAIN`, `WT_REPO` | every hook | The main checkout and its folder name |
| `WT_PATH`, `WT_BRANCH` | open, setup, serve, url, remove | The worktree and its branch |
| `WT_CREATED` | open | `1` for a new worktree, `0` for one that already existed |
| `WT_NAME` | open | A short name for the agent: `abc-1234`, `pr-1234`, or the branch |
| `WT_LABEL` | open | A readable title: the PR title, or a ticket branch without its number |
| `WT_PROMPT` | open | The agent's first message for a ticket or PR; empty otherwise |
| `WT_TICKET` | ticket-branch | The ticket ID, uppercased |
| `WT_DRY_RUN` | gc | `1` for `wt gc --dry-run`: say what would go, change nothing |

Your settings are passed along too, so a hook can read `WT_DB_PREFIX` or anything else you set.

Without `WT_ON_OPEN`, `wt new` runs `WT_ON_SETUP` itself and prints the path. With it, the hook takes over. The usual pattern is to open a pane running `wt serve`, which sets the worktree up first.

### Your own commands

`wt <name>` runs a `wt-<name>` executable from `WT_COMMANDS` or `PATH`, with your settings set. This is where commands that belong to your setup go, such as `wt review` to start a review agent, `wt scratch`, or `wt snapshot`.

## Commands

| Command | What it does |
|---|---|
| `wt new [target] [base]` | Makes a worktree for a branch, a PR (`pr:1234` or `#1234`), or a ticket (`ABC-1234`), then runs `WT_ON_OPEN`. A branch that already has a worktree is reopened, and one already on the remote is checked out. Asks for the target when you leave it out. |
| `wt setup` | Runs `WT_ON_SETUP` in this worktree |
| `wt serve` | Runs `WT_SERVE` in this checkout, setting a worktree up first if it hasn't been |
| `wt url` / `wt open` | Prints this checkout's URL, or opens it in the browser |
| `wt ls` | Every checkout with its PR, CI, uncommitted files, commits behind and ahead of the base, unpushed commits, and age |
| `wt path [branch]` | A branch's worktree path; without a branch, the main checkout's |
| `wt rm [--force] <branch>` | Runs `WT_ON_REMOVE`, removes the worktree, then runs `WT_ON_GC`. Keeps the branch, and refuses uncommitted changes without `--force`. |
| `wt prune` | Removes clean worktrees whose PR merged and deletes their branches. Asks about ones whose PR closed or that sat idle. Deletes merged branches that have no worktree. Keeps branches in a `gh stack` that's still in flight. |
| `wt gc [--dry-run]` | Forgets worktrees that were deleted some other way, then runs `WT_ON_GC` |
| `wt config` | The settings in effect here, and the commands found |

## Examples

[examples/](examples) has hooks to copy and adapt, and two working setups:

- **[herdr](examples/herdr)**: a workspace per worktree, with the agent, an editor, a terminal, and a server tab. It also adds `wt review`, `wt scratch`, and `wt layout`, plus key bindings.
- **[Herdr.app](examples/herdr-app)**: the same for the macOS app, with `wt key` for key bindings.
- **[tmux](examples/tmux)**: a window per worktree.
- **[rails-postgres](examples/rails-postgres)**: a Rails app on PostgreSQL. Each worktree gets its own databases, cloned in moments on btrfs or APFS. Its browser gets its own `https://<branch>.<app>.localhost` URL, and the databases are dropped when the worktree goes.
- **[linear](examples/linear)**: `wt new ABC-1234` finds the Linear issue's branch.

[How Gavin and Jeremy use it](examples/README.md#setups).

## Credits

`wt` started in [gavinomelia/herdr-config](https://github.com/gavinomelia/herdr-config). [Jeremy Walton](https://github.com/Jeremy-Walton/herdr-config) ported it to Herdr.app on macOS, and that port showed which parts were really `wt` and which were one person's setup.
