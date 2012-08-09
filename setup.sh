
function linkit() {
    tgt=~/.$1

    if [ ! -e $1 ] ; then
        echo "I can't find $1, check your code"
        exit 1
    fi

    if [ -e $tgt -a ! -h $tgt ] ; then
        echo "$1 looks like it is already setup... you should delete it first or move it so I don't break things"
        exit 1
    fi
    if [ -e $tgt -a -h $tgt ] ; then
        echo "Removing old symbolic link for $1"
        rm $tgt
    fi

    echo "Adding link for $1"
    ln -s `pwd`/$1 $tgt
}

linkit bashrc
linkit bash_profile
linkit vimrc

