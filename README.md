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

## Requirements

- bash (Linux, or macOS's stock bash 3.2) and git 2.31 or later
- Optional: [`gh`](https://cli.github.com) (signed in) and `jq`. They add `wt new pr:1234`, the PR and CI columns in `wt ls`, and merge detection in `wt prune`.

## Install

```sh
npm install -g @gavinomelia/wt
wt --version
```

From source:

```sh
git clone https://github.com/gavinomelia/wt ~/src/wt
npm install -g ~/src/wt        # or: ln -s ~/src/wt/bin/wt ~/.local/bin/wt
```

To upgrade, run `npm update -g @gavinomelia/wt`. Your settings and hooks live in `~/.config/wt` and are never touched. To uninstall, run `npm uninstall -g @gavinomelia/wt`.

## Set it up

### With your agent

Point your coding agent at [configure.md](configure.md) and say what you use. It looks at your setup, copies and adapts the [examples](examples), and checks the result:

```sh
claude "Read https://github.com/gavinomelia/wt/blob/main/configure.md and configure herdr to work with wt"
```

`configure.md` is installed with the package too: `$(npm root -g)/@gavinomelia/wt/configure.md`.

### By hand

`wt` works with no settings at all. In any repo, `wt new feature/x` does three things:

1. It fetches `origin/main` and branches from it.
2. It makes the worktree at `../worktrees/<repo>/feature-x`, beside your checkout.
3. It prints the path.

Settings live in two bash files of `NAME=value` lines:

- `~/.config/wt/config` holds settings for every repo, such as your terminal's hooks.
- `~/.config/wt/projects/<repo>.env` holds one repo's settings, where `<repo>` is its main checkout's folder name.

A `WT_*` variable already in the environment overrides both files, so `WT_AGENT=codex wt new` works even when the config sets `WT_AGENT=claude`. `wt config` shows what's in effect where you are.

Here's a minimal tmux setup with a Node app. It uses the [tmux example](examples/tmux), copied to `~/.config/wt/tmux/`.

`~/.config/wt/config`:

```sh
WT_ON_OPEN=$HOME/.config/wt/tmux/on-open
WT_ON_REMOVE=$HOME/.config/wt/tmux/on-remove
```

`~/.config/wt/projects/my-app.env`:

```sh
WT_ON_SETUP='cp "$WT_MAIN/.env" . && npm install'
WT_SERVE='exec npm run dev'
```

With these settings, `wt new feature/x` opens a tmux window with the agent, a shell, and `wt serve`. `wt serve` runs `npm install` the first time, then the dev server.

## Settings

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
| `WT_BASE`, `WT_REMOTE` | The branch new worktrees start from (default the remote's default branch, else `main`) and the remote (default `origin`) |
| `WT_IDLE_DAYS` | `wt prune` offers to remove a worktree with no PR after this many days without a commit (default 14) |
| `WT_COMMANDS` | Folders searched for `wt-<name>` commands, before `PATH` (default `~/.config/wt/commands`) |
| `WT_BROWSER` | What `wt open` opens the URL with (default `xdg-open`, or `open` on macOS) |
| `WT_CONFIG_DIR` | Where settings are read from (default `~/.config/wt`). Only works from the environment. |

Add any settings of your own, such as `WT_DB_PREFIX` or `WT_AGENT`. Hooks and commands see every setting.

## Hooks

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

`wt` runs the hooks at these points:

- **`wt new`** makes the worktree, unless the branch already has one, then runs `WT_ON_OPEN`. Without `WT_ON_OPEN`, it runs `WT_ON_SETUP` itself and prints the path. The usual `WT_ON_OPEN` opens a pane running `wt serve`, which sets the worktree up first.
- **`WT_ON_SETUP`** runs once per worktree. `wt` records that it succeeded in the worktree's git dir, and `wt setup` reruns it on demand.
- **`wt rm`** runs `WT_ON_REMOVE`. If that fails, the worktree stays. Otherwise `wt` removes the worktree, then runs `WT_ON_GC`.
- **`WT_ON_GC`** also runs before each new worktree, and after `wt prune`.

[configure.md](configure.md#4-the-hook-contract) has the rules a hook must follow.

### Your own commands

`wt <name>` runs a `wt-<name>` executable from `WT_COMMANDS` or `PATH`, with your settings set. This is where commands that belong to your setup go, such as `wt review` to start a review agent, `wt scratch`, or `wt snapshot`. `wt config` lists the ones it finds.

## Commands

| Command | What it does |
|---|---|
| `wt new [target] [base]` | Makes a worktree for a branch, a PR (`pr:1234` or `#1234`), or a ticket (`ABC-1234`), then runs `WT_ON_OPEN`. A branch that already has a worktree is reopened, and one already on the remote is checked out. Asks for the target when you leave it out. |
| `wt setup` | Runs `WT_ON_SETUP` in this worktree |
| `wt serve [args]` | Runs `WT_SERVE` in this checkout, setting a worktree up first if it hasn't been. `args` are passed on as `"$@"`. |
| `wt url` / `wt open` | Prints this checkout's URL, or opens it in the browser |
| `wt ls` | Every checkout with its PR, CI, uncommitted files, commits behind and ahead of the base, unpushed commits, and age |
| `wt path [branch]` | A branch's worktree path; without a branch, the main checkout's |
| `wt rm [--force] <branch>` | Removes a branch's worktree and keeps the branch. Refuses uncommitted changes without `--force`, and refuses the worktree you're in. |
| `wt prune` | Removes clean worktrees whose PR merged and deletes their branches. Asks about ones whose PR closed or that sat idle. Deletes merged branches that have no worktree. Keeps branches in a `gh stack` that's still in flight. |
| `wt gc [--dry-run]` | Forgets worktrees that were deleted some other way, then runs `WT_ON_GC` |
| `wt config` | The settings files, the settings in effect here, and the commands found |
| `wt help`, `wt --version` | Usage and version |

## Examples

[examples/](examples) has hooks to copy and adapt, and two working setups:

- **[herdr](examples/herdr)**: a workspace per worktree, with the agent, an editor, a terminal, and a server tab. It also adds `wt review`, `wt scratch`, and `wt layout`, plus key bindings.
- **[Herdr.app](examples/herdr-app)**: the same for the macOS app, with `wt key` for key bindings.
- **[tmux](examples/tmux)**: a window per worktree.
- **[rails-postgres](examples/rails-postgres)**: a Rails app on PostgreSQL. Each worktree gets its own databases, cloned in moments on btrfs or APFS. Its browser gets its own `https://<branch>.<app>.localhost` URL, and the databases are dropped when the worktree goes.
- **[linear](examples/linear)**: `wt new ABC-1234` finds the Linear issue's branch.

[How Gavin and Jeremy use it](examples/README.md#setups).

## Troubleshooting

- **A setting isn't taking effect.** Run `wt config` in the same directory. A repo's settings come from the file named after its main checkout's folder, and a `WT_*` variable in your environment overrides both files.
- **A key binding does nothing.** Key bindings often run outside any repo, so set `WT_MAIN`. Check that `wt` is on the `PATH` your terminal's server uses. With mise or nvm, that's usually the shims folder.
- **A hook fails.** Hooks are ordinary commands, so run one by hand with the variables it expects: `WT_PATH=... WT_BRANCH=... ~/.config/wt/tmux/on-open`. To trace `wt` itself, run `bash -x "$(command -v wt)" new my-branch`.
- **Before trusting a gc hook,** run `wt gc --dry-run`. It shows what would be deleted.

## Development

```sh
git clone https://github.com/gavinomelia/wt && cd wt
npm install -g .     # links bin/wt onto your PATH
npm test             # test/smoke.sh: wt against a throwaway repo with stub hooks
```

Keep `bin/wt` free of anything specific to one terminal, agent, or framework; those belong in hooks and `examples/`. Keep it running on macOS's bash 3.2: no `${var,,}`, `mapfile`, or GNU-only flags.
