EXTRAS=~/devel/other
mkdir -p $EXTRAS
cd $EXTRAS


# Data science toolkit
git clone https://github.com/jeroenjanssens/data-science-toolbox.git
cd data-science-toolbox
D=$(pwd)
for f in $(ls | grep -v README.md) ; do
    ln -s $D/$f ~/bin/
done

