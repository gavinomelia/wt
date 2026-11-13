# Configuring wt (for agents)

You're setting up `wt` for someone. The request usually sounds like "configure herdr to work with wt" or "set up wt for my Rails app". Read this file through first, then work through the steps. The [README](README.md) is the reference for every setting, hook, and command.

`wt` only manages git worktrees. Everything else goes through hooks that you write or copy into the user's config:

- the terminal or harness where a worktree opens;
- the agent that starts in it;
- how the app is set up and served;
- what's cleaned up afterwards.

Keep that split. Don't edit `wt` itself to fit one setup.

## 1. Check the install

```sh
wt --version     # installed? If not: npm install -g @gavinomelia/wt
wt config        # where settings are read from, what's in effect, where wt is installed
```

The examples ship with the package at `<install dir>/examples`. The install dir is the path `wt config` prints on its first line. They're also at https://github.com/gavinomelia/wt/tree/main/examples.

## 2. Find out what they use

Work out what you can yourself, by looking at their config files, the repo, and what's installed. Ask only about what's left.

- **Where worktrees should open.** herdr, Herdr.app, tmux, zellij, WezTerm, kitty, an editor, or nowhere (just print the path).
- **Which agent starts there.** Claude Code, Codex, or another, and what else they want beside it: an editor, a shell, a server.
- **Which repos.** For each one: the main checkout's path, the default branch, and the stack.
- **What a new worktree needs before the app runs.** Dependencies, copied env files or credentials, its own database. The repo's `bin/setup`, `README`, `Procfile*`, `docker-compose*`, and `.env*` usually say.
- **How the app runs, and at what URL.**
- **Their ticket tracker,** if they want `wt new ABC-1234`. Linear has an example.
- **Key bindings** they want for `wt new`, `wt ls`, `wt prune`, and the rest.

## 3. Start from an example

| They use | Start from |
|---|---|
| herdr (the terminal app) | `examples/herdr` |
| Herdr.app on macOS | `examples/herdr-app` |
| tmux | `examples/tmux` |
| Rails on PostgreSQL | `examples/rails-postgres` |
| Linear | `examples/linear` |

Each example folder has a `config` or `project.env` that says where its files go and which lines to add.

**Copy example files into the user's config. Don't point settings at the installed package,** because upgrades replace it. Put hooks for a terminal or harness beside that tool's own config (for herdr, `~/.config/herdr/wt/`) or under `~/.config/wt/<tool>/`. Put hooks for a project under `~/.config/wt/<name>/`. Then adapt the copies. For example, change the Devise model in `worktree_auto_login.rb`, or the processes in the `Procfile`.

For a tool with no example, write the hooks yourself (see step 4). Use `examples/tmux` as the model, since it's short.

## 4. The hook contract

The full table of variables is in the README. Whatever you write must keep to these rules.

- **`WT_ON_OPEN`** runs on every `wt new`, for new worktrees (`WT_CREATED=1`) and ones that already exist (`WT_CREATED=0`).
  - If the tool already has the worktree open (look it up by `WT_PATH`), focus that and stop.
  - Otherwise, open it at `WT_PATH`.
  - Start the agent with `WT_PROMPT` as its first message when it's set. For an existing worktree with no prompt, resume the agent's last session if the agent supports that (`claude --continue`).
  - When `WT_SERVE` is set, run `wt serve` in a second pane or tab. It sets the worktree up first, and the user sees the output.
  - Use `WT_NAME` for short names (agent, tab) and `WT_LABEL` for titles.
  - Print one line saying what happened.
- **`WT_ON_SETUP`** runs in the worktree. It must be safe to rerun: keep what's already there. `wt` records that it succeeded, so `wt serve` doesn't run it again. It uses a marker file in the worktree's git dir, never in the checkout.
- **`WT_SERVE`** runs from the checkout's root. End it with `exec` so signals reach the app.
- **`WT_ON_REMOVE`** closes what `WT_ON_OPEN` opened. It must never delete files, because `wt` removes the worktree after it. If it exits non-zero, `wt` keeps the worktree. Use that to refuse when closing would kill the pane running `wt`.
- **`WT_ON_GC`** cleans up anything that belonged to worktrees that no longer exist. Work out what's still in use from `git -C "$WT_MAIN" worktree list`, and never from a record of what was created, because worktrees are also deleted by hand. Honour `WT_DRY_RUN=1` by printing what would go and changing nothing.
- **`WT_TICKET_BRANCH`** prints just the branch name for the ticket in `WT_TICKET`, or nothing if it isn't found.
- Hooks get every setting as an environment variable. Read project values (database prefix, app name) from there rather than hard-coding them.
- Write hooks in bash that also runs on macOS's bash 3.2 when the user might be on a Mac. Avoid `${var,,}`, `mapfile`, and GNU-only flags.

Commands that belong to the setup rather than to `wt` go in a `wt-<name>` executable in a folder listed in `WT_COMMANDS`. Examples are `wt review`, `wt scratch`, and `wt snapshot`.

## 5. Write the settings

- `~/.config/wt/config`: settings for every repo. That's the harness hooks (`WT_ON_OPEN`, `WT_ON_REMOVE`), `WT_COMMANDS`, the agent, and `WT_MAIN`, the repo key bindings use when fired from outside a repo.
- `~/.config/wt/projects/<repo>.env`, where `<repo>` is the main checkout's folder name: the project hooks (`WT_ON_SETUP`, `WT_SERVE`, `WT_URL`, `WT_ON_GC`), ticket settings, and project values.

Settings files are bash, sourced in that order. A `WT_*` variable already in the environment overrides both, so a key binding can run `WT_AGENT=codex wt new` to change one setting for one run. Use `$HOME` rather than `~` in paths.

Then add key bindings to their terminal. Bind `wt new`, `wt ls`, and `wt prune` at least. These three need a terminal to read from or print to. In a popup that closes when the command exits, end with a read: `wt ls; read -rsn1`.

## 6. Verify

Run these in order, from the user's main checkout except where a step says otherwise. Don't skip any.

1. From outside any repo (`cd ~`), run `wt config` and `wt path` if they set `WT_MAIN`. Key bindings often run from there.
2. Run `wt config`. Both settings files should be found, every hook path should exist and be executable, and the expected commands should be listed.
3. Run `wt gc --dry-run` **before anything that removes worktrees.** `wt new`, `wt rm`, and `wt prune` all run the gc hook, and a gc hook that misreads which worktrees are live will drop real data. Every name it lists must really be unused. If one isn't, fix the hook first.
4. Run `wt new wt-config-test` and check that it opens where it should, the agent starts, and setup and serve work. Then run `wt new wt-config-test` again. It should focus the same place, not open a second one.
5. From another checkout, run `wt rm wt-config-test`, then `git branch -D wt-config-test`. Check that what opened has closed.
6. Run `wt ls`.

Finally, tell the user which files you wrote, the key bindings, and anything you couldn't test.
