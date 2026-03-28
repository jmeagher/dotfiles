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

# Set up Claude Code configuration
sh "$(pwd)/claude/setup.sh"

echo "Hit enter to install vundle bundles, ctrl-c to skip"
read a
vim +BundleInstall +qall


