#!/bin/bash

source .env
cd "$ORG_DIRECTORY"
EVENTS="close_write,move,delete,create";
INCOMMAND="inotifywait -qr -e \"$EVENTS\" --exclude \"\.git\" \"$ORG_DIRECTORY\" --format \"%w%f\""
while true; do
    files=$(eval $INCOMMAND | grep -i *.org)
    echo $files
    for file in "$files"; do
        emacs --batch --eval="(progn (load-file \"$HOME/.emacs.d/early-init.el\") (load-file \"$HOME/.emacs.d/init.el\" ) (find-file \"$file\") (org-transclusion-mode t) (org-html-export-to-html))"
        emacs --batch --eval="(progn (load-file \"$HOME/.emacs.d/early-init.el\") (load-file \"$HOME/.emacs.d/init.el\" ) (find-file \"$file\") (org-transclusion-mode t) (org-html-export-to-html))"
    done
done
