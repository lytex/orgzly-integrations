#!/bin/bash

LOGFILE="$HOME/git-sync.log"

if command -v "termux-info" &>/dev/null ; then
    NOTIF_CMD="termux-notification"
    NOTIF_ERROR="$NOTIF_CMD -t git-sync -c ERROR --id error --ongoing"
elif [ "$(uname -m)" == "armv7l" ]; then
    NOTIF_CMD="echo `date`"
    NOTIF_ERROR="$NOTIF_CMD git-sync ERROR -t 0"
else
    NOTIF_CMD="notify-send"
    NOTIF_ERROR="$NOTIF_CMD git-sync ERROR -t 0"
fi

command -v "$NOTIF_CMD" &>/dev/null || { stderr "Error: Required command '$NOTIF_CMD' not found"; exit 1; }

test $GIT_SYNC_DIRECTORY && cd $GIT_SYNC_DIRECTORY

while true; do
    $NOTIF_CMD "git-sync_started"
    ./git-sync.sh >> $LOGFILE 2>&1 || $NOTIF_ERROR
    $NOTIF_CMD "git-sync_restarted"
done
