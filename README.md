# wt

One git worktree per branch, so several coding agents can each work on their own branch of the same repo at once.

`wt` does the git part: it makes the worktree, finds the branch for a PR or ticket, reports which worktrees have merged, and cleans up. Everything else is a command you choose in its settings:

- where a worktree opens (a herdr workspace, a tmux window, a Herdr.app space, or just a path);
- how it's set up (its own database, copied dependencies);
- how the app runs, and what's cleaned up after it.

`wt init` writes those settings for you, and sets up a Rails app on PostgreSQL if you press enter at every question. Nothing in `wt` itself depends on a terminal, agent, or framework.

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

With nodenv, nvm, mise, or asdf, global npm packages belong to one Node version. Run the install from your home folder (`cd ~` first) so it goes into your default version. A project that pins a different Node version won't find `wt`, and changing your default version means installing again. Installing from source avoids both, because `wt` doesn't need Node.

From source:

```sh
git clone https://github.com/gavinomelia/wt ~/src/wt
~/src/wt/bin/install
```

`bin/install` links `wt` into `~/.local/bin`. If it prints a line to add to your shell profile, add it to `~/.zshrc` (or `~/.bashrc`), then open a new terminal.

To upgrade, run `npm update -g @gavinomelia/wt`, or `git pull` in your clone. Your settings and scripts live in `~/.config/wt` and are never touched. To uninstall, run `npm uninstall -g @gavinomelia/wt`, or `rm ~/.local/bin/wt` and delete the clone.

## Set it up

### With wt init

Run it in your repo and answer a few questions. Each has a default in brackets, so pressing enter all the way through sets up a Rails app on PostgreSQL:

```sh
cd ~/code/my_app
wt init          # or wt init --yes to take every default
```

| Question | Default |
|---|---|
| Project type: `rails-postgres` or `custom` | `rails-postgres` |
| Database prefix | From `config/database.yml`: `my_app` for `my_app_development` |
| App name for [portless](https://github.com/vercel-labs/portless) URLs | The repo's name |
| Procfile `wt serve` runs | The repo's `Procfile.dev`, or the example Procfile |
| Email to sign every worktree's browser in as | none |
| Ticket key, for `wt new ABC-1234` through Linear | The most common `<key>-<number>-` prefix among your branches |
| Where worktrees open: `herdr`, `herdr-app`, `tmux`, or `none` | The terminal you're running it in |

`custom` asks for three commands instead: one that sets up a new worktree, one that runs the app, and one that prints its URL.

`wt init` copies the scripts it needs from [examples](examples) into `~/.config/wt`, where you can change them. It writes the project's settings to `~/.config/wt/projects/<repo>.env`, and the terminal settings to `~/.config/wt/config`. It never replaces a script that's already there. It asks before replacing project settings, and leaves terminal settings alone if they exist. At the end it lists what the app needs before the first `wt new`. For rails-postgres, that's an app that reads its database names from `.env_overrides.rb`.

### With your agent

Point your coding agent at [configure.md](configure.md) and say what you use. It looks at your setup, copies and adapts the [examples](examples), and checks the result:

```sh
claude "Read https://github.com/gavinomelia/wt/blob/main/configure.md and configure herdr to work with wt"
```

`configure.md` is installed with the package too: `$(npm root -g)/@gavinomelia/wt/configure.md`.

### By hand

**With no settings, `wt` only does git.** `wt new feature/x` fetches `origin/main`, makes a worktree from it at `../worktrees/<repo>/feature-x` (beside your checkout), and prints the path. `wt ls`, `wt rm`, and `wt prune` work too. Nothing gets installed, served, or opened, because `wt` doesn't guess how your project works.

**Settings tell it the rest.** They live in two files of `NAME=value` lines:

| File | What goes in it |
|---|---|
| `~/.config/wt/projects/<repo>.env` | How one project is set up and run. `<repo>` is the main checkout's folder name. |
| `~/.config/wt/config` | Settings for every repo, such as where worktrees open |

Run `wt config` in a repo to see which files it read and what's in effect. A `WT_*` variable set on the command line beats both files, so `WT_AGENT=codex wt new` works even when the config says `WT_AGENT=claude`.

#### Set up and run your project

Each of these is a command you choose. It runs from the worktree's root, and nothing happens when it isn't set.

| Setting | Runs | Example |
|---|---|---|
| `WT_ON_SETUP` | Once per new worktree, before its first `wt serve`, and on `wt setup` | `npm install` |
| `WT_SERVE` | On `wt serve` | `exec npm run dev` |
| `WT_URL` | On `wt url` and `wt open`, and should print the URL | `echo http://localhost:3000` |

For a Node app, `~/.config/wt/projects/my-app.env` could be:

```sh
WT_ON_SETUP='cp "$WT_MAIN/.env" . && npm install'
WT_SERVE='exec npm run dev'
```

Now `wt serve` in a new worktree copies `.env`, runs `npm install`, and starts the dev server. Later runs go straight to the dev server. Any stack works the same way: put in the commands you'd type by hand. For setups that need more than a line, such as a database per worktree, point the setting at a script. [rails-postgres](examples/rails-postgres) is one.

#### Open worktrees in your terminal

`WT_ON_OPEN` and `WT_ON_REMOVE` decide where a worktree opens and how it closes. They're usually scripts from [examples](examples). For tmux, copy [examples/tmux](examples/tmux) to `~/.config/wt/tmux/` and add to `~/.config/wt/config`:

```sh
WT_ON_OPEN=$HOME/.config/wt/tmux/on-open
WT_ON_REMOVE=$HOME/.config/wt/tmux/on-remove
```

Now `wt new feature/x` opens a tmux window with the agent, a shell, and `wt serve` running. `wt rm feature/x` closes it.


## Settings

The first seven settings each hold a command, usually the path to a script. `wt` runs it at the moment the table says.

| Setting | The command it runs |
|---|---|
| `WT_ON_OPEN` | Opens a worktree, new or existing, in your terminal (on `wt new`) |
| `WT_ON_SETUP` | Sets up a new worktree (on `wt setup`, and before the first `wt serve`) |
| `WT_SERVE` | Runs the app (on `wt serve`) |
| `WT_URL` | Prints the checkout's URL (on `wt url` and `wt open`) |
| `WT_ON_REMOVE` | Closes what `WT_ON_OPEN` opened (on `wt rm`, before the worktree is removed) |
| `WT_ON_GC` | Cleans up after worktrees that are gone, such as their databases (on `wt gc`, `wt rm`, `wt prune`, and `wt new`) |
| `WT_TICKET_BRANCH` | Prints a ticket's branch name, from `WT_TICKET` (on `wt new ABC-1234`) |

The rest are values:

| Setting | What it's for |
|---|---|
| `WT_TICKET_PREFIX` | Your ticket key (`abc` for ABC-1234), so `wt new ABC-1234` works |
| `WT_TICKET_PROMPT`, `WT_PR_PROMPT` | The agent's first message for a ticket or PR; `%s` is its ID |
| `WT_MAIN` | The repo to use when you run `wt` outside one, such as from a key binding |
| `WT_DIR` | Where worktrees go (default `<main checkout's parent>/worktrees/<repo>`) |
| `WT_BASE`, `WT_REMOTE` | The branch new worktrees start from (default the remote's default branch, else `main`) and the remote (default `origin`) |
| `WT_IDLE_DAYS` | `wt prune` offers to remove a worktree with no PR after this many days without a commit (default 14) |
| `WT_COMMANDS` | Folders searched for `wt-<name>` commands, before `PATH` (default `~/.config/wt/commands`) |
| `WT_BROWSER` | What `wt open` opens the URL with (default `xdg-open`, or `open` on macOS) |
| `WT_CONFIG_DIR` | Where settings are read from (default `~/.config/wt`). Only works from the environment. |

Add any settings of your own, such as `WT_DB_PREFIX` or `WT_AGENT`. Every command `wt` runs can read them.

### What those commands are given

`wt` runs each command with bash, from the checkout's root, and passes it what it needs as environment variables:

| Variable | Given to | Value |
|---|---|---|
| `WT_MAIN`, `WT_REPO` | all of them | The main checkout and its folder name |
| `WT_PATH`, `WT_BRANCH` | `WT_ON_OPEN`, `WT_ON_SETUP`, `WT_SERVE`, `WT_URL`, `WT_ON_REMOVE` | The worktree and its branch |
| `WT_CREATED` | `WT_ON_OPEN` | `1` for a new worktree, `0` for one that already existed |
| `WT_NAME` | `WT_ON_OPEN` | A short name for the agent: `abc-1234`, `pr-1234`, or the branch |
| `WT_LABEL` | `WT_ON_OPEN` | A readable title: the PR title, or a ticket branch without its number |
| `WT_PROMPT` | `WT_ON_OPEN` | The agent's first message for a ticket or PR; empty otherwise |
| `WT_TICKET` | `WT_TICKET_BRANCH` | The ticket ID, uppercased |
| `WT_DRY_RUN` | `WT_ON_GC` | `1` for `wt gc --dry-run`: say what would go, change nothing |

A few things to know about when they run:

- Without `WT_ON_OPEN`, `wt new` runs `WT_ON_SETUP` itself and prints the path. With it, the usual pattern is to open a pane running `wt serve`, which runs setup first.
- `WT_ON_SETUP` runs once per worktree. `wt` records that it succeeded in the worktree's git dir, and `wt setup` runs it again on demand.
- If `WT_ON_REMOVE` fails, `wt rm` keeps the worktree.

[configure.md](configure.md#4-what-each-command-must-do) has the rules for writing your own.

### Adding subcommands

`wt <name>` runs an executable called `wt-<name>`, found in `WT_COMMANDS` or on `PATH`, with your settings set. Subcommands that belong to your setup go there, such as `wt review` to start a review agent, `wt scratch`, or `wt snapshot`. `wt config` lists the ones it finds.

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
| `wt init [--yes]` | Writes settings for the repo you're in, asking a few questions (see [Set it up](#with-wt-init)) |
| `wt config` | The settings files, the settings in effect here, and the subcommands found |
| `wt help`, `wt --version` | Usage and version |

## Examples

[examples/](examples) has scripts for these settings to copy and adapt (`wt init` copies the ones you pick), and two working setups:

- **[herdr](examples/herdr)**: a workspace per worktree, with the agent, an editor, a terminal, and a server tab. It also adds `wt review`, `wt scratch`, and `wt layout`, plus key bindings.
- **[Herdr.app](examples/herdr-app)**: the same for the macOS app, with `wt key` for key bindings.
- **[tmux](examples/tmux)**: a window per worktree.
- **[rails-postgres](examples/rails-postgres)**: a Rails app on PostgreSQL. Each worktree gets its own databases, cloned in moments on btrfs or APFS. Its browser gets its own `https://<branch>.<app>.localhost` URL, and the databases are dropped when the worktree goes.
- **[linear](examples/linear)**: `wt new ABC-1234` finds the Linear issue's branch.

[How Gavin and Jeremy use it](examples/README.md#setups).

## Troubleshooting

- **`wt: command not found` in one project.** With a Node version manager, an npm install lives in one Node version, and that project pins another. Install from your home folder, or [from source](#install).
- **A setting isn't taking effect.** Run `wt config` in the same directory. A repo's settings come from the file named after its main checkout's folder, and a `WT_*` variable in your environment overrides both files.
- **A key binding does nothing.** Key bindings often run outside any repo, so set `WT_MAIN`. Check that `wt` is on the `PATH` your terminal's server uses. With mise or nvm, that's usually the shims folder.
- **A script from your settings fails.** They're ordinary commands, so run one by hand with the variables it expects: `WT_PATH=... WT_BRANCH=... ~/.config/wt/tmux/on-open`. To trace `wt` itself, run `bash -x "$(command -v wt)" new my-branch`.
- **Before trusting `WT_ON_GC`,** run `wt gc --dry-run`. It shows what would be deleted.

## Development

```sh
git clone https://github.com/gavinomelia/wt && cd wt
bin/install          # links bin/wt into ~/.local/bin
npm test             # test/smoke.sh: wt against a throwaway repo with stub settings
```

Keep `bin/wt` free of anything specific to one terminal, agent, or framework; those belong in settings and `examples/`. `wt init` is the one place that knows about the examples. Keep it running on macOS's bash 3.2: no `${var,,}`, `mapfile`, or GNU-only flags.

CI (`.github/workflows/check.yml`) runs `npm test` on every push, and installs the packed tarball to check that `wt --version` works.

### Releasing

Pushing a `v*` tag publishes to npm through `.github/workflows/release.yml`. It runs `npm test`, stops if the tag doesn't match the `package.json` version, then runs `npm publish --provenance`. It needs no npm token, because npm trusts the workflow (trusted publishing).

```sh
npm version patch   # or minor / major: bumps package.json, commits, and tags
git push --follow-tags
```

Before the first tagged release, open the package's settings on npmjs.com and add a trusted publisher: GitHub Actions, repository `gavinomelia/wt`, workflow `release.yml`.

## License

[MIT](LICENSE)
