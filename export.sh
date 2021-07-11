#!/bin/bash

source .env
cd "$ORG_DIRECTORY"
EVENTS="close_write,move,delete,create";
INCOMMAND="inotifywait -qr -e \"$EVENTS\" --exclude \"\.git\" \"$ORG_DIRECTORY\" --format \"%w%f\""
while true; do
    files=$(eval $INCOMMAND | grep -i *.org)
    echo $files
    for file in "$files"; do
        echo emacs --script "$HOME/.emacs.d/early-init.el" --script "$HOME/.emacs.d/init.el" --eval="(progn (find-file \"$file\") (org-transclusion-mode t) (org-html-export-to-html))"
        emacs --script "$HOME/.emacs.d/early-init.el" --script "$HOME/.emacs.d/init.el" --eval="(progn (find-file \"$file\") (org-transclusion-mode t) (org-html-export-to-html))"
    done
done
