#!/bin/bash

source .env
cd "$ORG_DIRECTORY"
EVENTS="close_write,move,delete,create";
INCOMMAND="inotifywait -qr -e \"$EVENTS\" --exclude \"\.git\" \"$ORG_DIRECTORY\""
while true; do
    files=$(eval $INCOMMAND | grep -i *.org)
    for file in "$files"; do
        echo emacs --batch --eval="(progn (find-file \"$file\") (org-transclusion-mode t) (org-html-export-to-html))"
        emacs --batch --eval="(progn (find-file \"$file\") (org-transclusion-mode t) (org-html-export-to-html))"
    done
done
