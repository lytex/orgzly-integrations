#!/bin/bash

false # This makes $? != 0 at the beggining of the while loop

while (($? != 0)); do

    timeout 1h \
    emacs -l "$HOME/.emacs.d/early-init.el" -l "$HOME/.emacs.d/init.el" --batch \
    --eval="(progn (add-to-list 'auth-sources \"~/.auth info\") (org-caldav-sync-calendar) (org-save-all-org-buffers))"

done