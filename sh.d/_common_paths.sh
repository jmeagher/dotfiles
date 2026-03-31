# Prepends
for P in \
    /opt/homebrew/bin \
    /usr/local/bin \
    /usr/local/sbin \
    ; do
  [[ -d $P ]] && PATH="$P:$PATH"
done

# Appends
for P in \
    ~/.local/bin \
    ~/.local/sbin \
    ~/bin \
    ; do
  [[ -d $P ]] && PATH="$PATH:$P"
done

export PATH
    
