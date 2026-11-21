#!/bin/sh
# Link the portable parts of the Herdr desktop app config into ~/.config/herdr-app.
#
# The app writes its own state (view.json, shared.json, layouts/.state/, frame/,
# icons/, AGENTS.md, ...) into that directory, so it is NOT symlinked as a whole.
# Only files tracked here are linked, one by one. Shipped files (themes/atom-one-dark.json,
# layouts/main.json, default mods) are left alone: clone them under a new name to customize.
#
# Existing regular files are moved to <name>.pre-dotfiles instead of aborting, because the
# app creates default settings.json / keys.json on first launch.

set -e

src_root="$(cd "$(dirname "$0")" && pwd)"
dest_root="${HERDR_APP_CONFIG_DIR:-$HOME/.config/herdr-app}"

link_item() {
    src=$1
    tgt=$2
    mkdir -p "$(dirname "$tgt")"
    if [ -h "$tgt" ]; then
        rm "$tgt"
    elif [ -e "$tgt" ]; then
        echo "Backing up existing $tgt -> $tgt.pre-dotfiles"
        mv "$tgt" "$tgt.pre-dotfiles"
    fi
    echo "Linking $tgt"
    ln -s "$src" "$tgt"
}

for f in settings.json keys.json programs.json; do
    [ -f "$src_root/$f" ] && link_item "$src_root/$f" "$dest_root/$f"
done

for f in "$src_root"/layouts/*.json "$src_root"/layouts/*.svg "$src_root"/layouts/*.png \
         "$src_root"/themes/*.json; do
    [ -f "$f" ] || continue
    link_item "$f" "$dest_root/${f#$src_root/}"
done

for d in "$src_root"/mods/*/; do
    [ -d "$d" ] || continue
    d=${d%/}
    link_item "$d" "$dest_root/mods/$(basename "$d")"
done
