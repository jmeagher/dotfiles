# dotfiles — Project Notes for Claude

## Repo Purpose

Personal dotfiles and tooling. Managed via symlinks: `setup.sh` links config files into `~/` and calls `claude/setup.sh` for Claude Code setup.

## Structure

```
setup.sh                  # Main setup — symlinks dotfiles, builds urllist, calls claude/setup.sh
shell_config.sh           # Shell entry point: sources sh.d/, then bash.d/ or zsh.d/

sh.d/                     # Shell config shared by bash and zsh (aliases, env, tool setup)
bash.d/                   # Bash-only config (completion, prompt, extras)
zsh.d/                    # Zsh-only config (prompt)

bin/                      # Scripts symlinked into ~/bin
urllist/                  # Go tool (built by setup.sh into bin/urllist)

claude/                   # Claude Code config templates (NOT installed directly)
  CLAUDE.md               # Global CLAUDE.md template — symlinked to ~/.claude/CLAUDE.md
  settings.json           # Base settings template — setup.sh generates ~/.claude/settings.json
  setup.sh                # Injects marketplace path + statusline path into settings.json
  statusline.sh           # Statusline script referenced by settings.json

plugins/                  # Claude Code plugins (jmeagher-dotfiles marketplace)
  jmeagher-notifications/ # macOS/tmux notifications for Claude events
  jpm/                    # Personal git and workflow commands
    commands/home.md      # /home — switch to main/master and pull

.claude-plugin/
  marketplace.json        # Marketplace index — lists all plugins in plugins/

osx/                      # macOS-specific config (iTerm2, Slate window manager)
vim/                      # Vim config and plugins (Vundle)
vimrc                     # Vim config (symlinked to ~/.vimrc)
gitconfig                 # Git config (symlinked to ~/.gitconfig)
tmux.conf                 # tmux config (symlinked to ~/.tmux.conf)
oldstuff/                 # Archived/unused configs
```

## Key Conventions

**Shell config** — `shell_config.sh` is the single entry point sourced by `.bashrc`/`.zshrc`/`.bash_profile`. Add shared aliases/env to `sh.d/`, shell-specific things to `bash.d/` or `zsh.d/`.

**Claude settings** — `claude/settings.json` is a template; the live file is `~/.claude/settings.json`. Edit the template, then run `bash claude/setup.sh` to regenerate. The setup script injects the marketplace path and statusline path.

**Local overrides** — machine-specific Claude settings go in `~/.claude/settings.local.json` (not tracked in this repo). Machine-specific shell config goes in `~/CLAUDE.local.md` (referenced via `@` import).

## Claude Plugins (jmeagher-dotfiles marketplace)

When adding a new plugin under `plugins/`, you must also add an entry for it in `.claude-plugin/marketplace.json`. The marketplace uses an explicit index — it does not scan the directory automatically. Without this, the plugin won't appear and can't be installed.

After updating `marketplace.json`, run:
```
claude plugin marketplace update jmeagher-dotfiles
claude plugin install <plugin-name>@jmeagher-dotfiles
```
