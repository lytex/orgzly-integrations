#!/bin/sh

# crontab uses /bin/sh, so the command is:
/bin/bash -c '/snap/bin/emacs -l "/home/pi/.emacs.d/early-init.el" -l "/home/pi/.emacs.d/init.el" --batch --eval="(progn (add-to-li
st '"'"'auth-sources \"/home/pi/.authinfo\") (org-caldav-sync-calendar) (org-save-all-org-buffers))"'