# Examples

Scripts for wt's settings, and subcommands, to copy into your own config and adapt. `wt init` copies the ones you pick; otherwise each folder's `config` or `project.env` says where its files go.

| Folder | What it does |
|---|---|
| [herdr](herdr) | Opens each worktree as a [herdr](https://herdr.dev) workspace. The "code" tab has the agent left, an editor right, and a terminal along the bottom. A "server" tab runs `wt serve`. It adds `wt review` (Codex reviews the branch in a split), `wt scratch`, and `wt layout`, and `keys.toml` has key bindings. |
| [herdr-app](herdr-app) | The same for Herdr.app on macOS, through `herdr-app do`. `wt key <command>` runs a command from a key binding and closes its tab afterwards, and `keys.wt.json` has the bindings. |
| [tmux](tmux) | Opens each worktree as a tmux window: the agent, a shell, and `wt serve`. |
| [rails-postgres](rails-postgres) | Sets up a Rails app on PostgreSQL. Each worktree gets its own dev and test databases, cloned from an idle snapshot (`wt snapshot`). It symlinks the credentials keys, copies `node_modules` and built assets copy-on-write, and can sign the browser straight in. `wt serve` runs a Procfile with foreman, and its `WT_ON_GC` script drops databases no checkout uses. |
| [linear](linear) | `wt new ABC-1234` asks Claude Code's Linear connector for the issue's branch. No API key is needed. |

## Setups

### Gavin: herdr on Linux, Rails on PostgreSQL

Omarchy (Arch Linux) running [herdr](https://herdr.dev), with Claude Code, or Codex when Claude's usage runs out. The app is a Rails app on PostgreSQL 18 on btrfs, so database clones take moments. Tickets are in Linear, and [portless](https://github.com/vercel-labs/portless) gives each branch its own `https://<branch>.<app>.localhost`.

| Example | Copied to |
|---|---|
| `herdr/` | `~/.config/herdr/wt/` (alongside his [herdr config](https://github.com/gavinomelia/herdr-config)) |
| `herdr/keys.toml` | merged into `~/.config/herdr/config.toml` |
| `rails-postgres/` | `~/.config/wt/rails-postgres/` |
| `linear/ticket-branch` | `~/.config/wt/linear/` |

`~/.config/wt/config`:

```sh
# Key bindings fire from whatever pane has focus, so this is the repo they use outside one
WT_MAIN=$HOME/Work/my_app

H=$HOME/.config/herdr/wt
WT_ON_OPEN=$H/on-open
WT_ON_REMOVE=$H/on-remove
WT_COMMANDS=$HOME/.config/wt/commands:$H:$HOME/.config/wt/rails-postgres

WT_AGENT=claude
WT_EDITOR_COMMAND="slice -w"
```

`~/.config/wt/projects/my_app.env`:

```sh
R=$HOME/.config/wt/rails-postgres
WT_ON_SETUP=$R/setup
WT_SERVE=$R/serve
WT_ON_GC=$R/gc
WT_DB_PREFIX=my_app
WT_APP=my-app
WT_URL='portless get "$WT_APP"'
WT_PROCFILE=$HOME/.config/wt/my_app/Procfile
WT_AUTO_LOGIN_EMAIL=me@example.com

WT_TICKET_PREFIX=abc
WT_TICKET_BRANCH=$HOME/.config/wt/linear/ticket-branch
WT_TICKET_PROMPT='Read Linear issue %s with get_issue and list_comments. Summarize what it asks for and any open questions, then wait for instructions.'
```

A day with it:

| Key | Runs | What happens |
|---|---|---|
| alt+t | `wt new` | Type `ABC-1234`. A workspace named after the issue opens with Claude reading it. The server tab clones the database, migrates, and starts the app at `https://abc-1234-….my-app.localhost`. |
| alt+shift+t | `WT_AGENT=codex wt new` | The same, with Codex |
| alt+t | `wt new` | Type `pr:1234` to review a teammate's PR in its own worktree |
| alt+r | `wt review` | Codex reviews the branch in a split, read-only |
| alt+o | `wt open` | Opens this worktree's app in the browser |
| alt+s | `wt scratch` | A side tab on the same checkout for questions |
| alt+w | `wt ls` | Lists every worktree with its PR and CI |
| alt+shift+w | `wt prune` | Removes worktrees whose PRs merged and drops their databases |

### Jeremy: Herdr.app on macOS, Rails on PostgreSQL

macOS running Herdr.app with Jeremy's own layout and mods. The app is Rails on PostgreSQL 18 on APFS. Like Gavin's, it uses Linear and portless. The app has its `Procfile.pdev` in the repo, and his snapshot database is `<prefix>_snapshot`. This setup replaced the macOS port of `wt` his [herdr-config](https://github.com/Jeremy-Walton/herdr-config) used to carry, and runs on his Mac.

| Example | Copied to |
|---|---|
| `herdr-app/` | `~/.config/wt/herdr-app/` |
| `herdr-app/keys.wt.json` | merged into Herdr's key bindings |
| `rails-postgres/` | `~/.config/wt/rails-postgres/` |
| `linear/ticket-branch` | `~/.config/wt/linear/` |

`~/.config/wt/config`:

```sh
H=$HOME/.config/wt/herdr-app
WT_ON_OPEN=$H/on-open
WT_ON_REMOVE=$H/on-remove
WT_COMMANDS=$HOME/.config/wt/commands:$H:$HOME/.config/wt/rails-postgres
WT_AGENT=claude
WT_EDITOR_COMMAND=nvim
```

`~/.config/wt/projects/my_app.env`:

```sh
R=$HOME/.config/wt/rails-postgres
WT_ON_SETUP=$R/setup
WT_SERVE=$R/serve
WT_ON_GC=$R/gc
WT_DB_PREFIX=my_app
WT_SNAPSHOT_DB=my_app_snapshot
WT_APP=my-app
WT_URL='portless get "$WT_APP"'
WT_PROCFILE=Procfile.pdev
WT_AUTO_LOGIN_EMAIL=me@example.com

WT_TICKET_PREFIX=abc
WT_TICKET_BRANCH=$HOME/.config/wt/linear/ticket-branch
```

His key bindings are `cmd-shift-t` (`wt key new`), `cmd-alt-t` (with Codex), `cmd-shift-s` (scratch), `cmd-shift-o` (open), `cmd-alt-w` (ls), `cmd-alt-shift-w` (prune), and `cmd-shift-r` (review, in a pane on the right).
