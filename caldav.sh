#!/bin/bash

function retry_sync() {

    false # This makes $? != 0 at the beggining of the while loop

    while (($? != 0)); do
        emacs -l "$HOME/.emacs.d/early-init.el" -l "$HOME/.emacs.d/init.el" --batch \
            --eval="(progn (add-to-list 'auth-sources \"~/.auth info\") (org-caldav-sync-calendar) (org-save-all-org-buffers))"
    done

}

timeout 1h retry_sync

