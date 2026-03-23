#!/bin/sh

linkit() {
    tgt=~/$2
    src=$1


    if [ ! -e $src ] ; then
        echo "I can't find $src, check your code"
        exit 1
    fi

    if [ -e $tgt -a ! -h $tgt ] ; then
        echo "$src looks like it is already setup... you should delete it first or move it so I don't break things"
        exit 1
    fi
    if [ -e $tgt -a -h $tgt ] ; then
        echo "Removing old symbolic link for $src"
        rm $tgt
    fi

    echo "Adding link for $src"
    ln -s `pwd`/$src $tgt
}

linkit ./ .mydotfiles
linkit zshrc .zshrc
linkit bashrc .bashrc
linkit bash_profile .bash_profile
linkit vimrc .vimrc
linkit vim .vim
linkit tmux.conf .tmux.conf
linkit gitconfig .gitconfig
linkit gitignore_global .gitignore_global
linkit osx/slate/slate_local.js .slate_local.js

mkdir -p ~/bin

# Build urllist Go binary
if command -v go > /dev/null 2>&1 ; then
    echo "Building urllist Go binary..."
    (cd urllist && go build -o ../bin/urllist .)
else
    echo "WARNING: Go is not installed, urllist binary won't be built"
fi

# Link everything from bin to ~/bin
for f in `ls bin/* | grep -v "~"` ; do
    linkit $f $f
done

# A little extra vim setup
if [ ! -e vim/bundle/Vundle.vim ] ; then
    git clone https://github.com/VundleVim/Vundle.vim.git ~/.vim/bundle/Vundle.vim
fi

# Set up Claude Code statusline symlink
STATUSLINE_SRC="$HOME/.claude/plugins/cache/jmeagher-dotfiles/statusline/1.0.0/scripts/statusline.sh"
STATUSLINE_LINK="$HOME/.claude/statusline.sh"
if [ -f "$STATUSLINE_SRC" ]; then
    echo "Linking Claude Code statusline script"
    ln -sf "$STATUSLINE_SRC" "$STATUSLINE_LINK"
else
    echo "WARNING: statusline plugin not installed; skipping ~/.claude/statusline.sh symlink"
    echo "  Install with: /plugin install statusline@jmeagher-dotfiles"
fi

# Set up Claude Code configuration
DOTFILES_DIR="$(pwd)"
mkdir -p "$HOME/.claude"

# CLAUDE.md: symlink base file (which @-imports ~/CLAUDE.local.md for machine-specific additions)
linkit claude/CLAUDE.md .claude/CLAUDE.md

# ~/CLAUDE.local.md: create a stub if not present (local/work repo may symlink a real one here)
if [ ! -e "$HOME/CLAUDE.local.md" ] ; then
    echo "Creating stub ~/CLAUDE.local.md (replace with symlink from your local settings repo)"
    printf '# Local Claude settings\n\n# Add machine-specific instructions here.\n' > "$HOME/CLAUDE.local.md"
fi

# settings.json: generate from base template, injecting the dotfiles marketplace path
# Local overrides go in ~/.claude/settings.local.json (symlinked from local/work repo)
CLAUDE_SETTINGS="$HOME/.claude/settings.json"
SETTINGS_BASE="$DOTFILES_DIR/claude/settings.json"
if command -v jq > /dev/null 2>&1 ; then
    echo "Generating ~/.claude/settings.json from dotfiles base"
    jq --arg path "$DOTFILES_DIR" \
        '.extraKnownMarketplaces["jmeagher-dotfiles"] = {"source": {"source": "directory", "path": $path}, "autoUpdate": true}' \
        "$SETTINGS_BASE" > "$CLAUDE_SETTINGS"
else
    echo "WARNING: jq not found; copying settings.json without marketplace path injection"
    echo "  Install jq and re-run setup.sh, or manually add jmeagher-dotfiles to ~/.claude/settings.json"
    cp "$SETTINGS_BASE" "$CLAUDE_SETTINGS"
fi

echo "Hit enter to install vundle bundles, ctrl-c to skip"
read a
vim +BundleInstall +qall


