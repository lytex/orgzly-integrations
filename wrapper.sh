#!/bin/bash

LOGFILE="$HOME/git-sync.log"

if command -v "termux-info" &>/dev/null ; then
    NOTIF_CMD="termux-notification"
    NOTIF_ERROR="$NOTIF_CMD -t git-sync -c ERROR --id error --ongoing"
    NOTIF_START="$NOTIF_CMD -t git-sync_started"
    NOTIF_RESTART="$NOTIF_CMD -t git-sync_restarted"
elif [ "$(uname -m)" == "armv7l" ]; then
    NOTIF_CMD="echo `date`"
    NOTIF_ERROR="$NOTIF_CMD git-sync ERROR -t 0"
    NOTIF_START="$NOTIF_CMD git-sync_started"
else
    NOTIF_CMD="notify-send"
    NOTIF_ERROR="$NOTIF_CMD git-sync ERROR -t 0"
    NOTIF_START="$NOTIF_CMD git-sync_started"
fi

command -v "$NOTIF_CMD" &>/dev/null || { stderr "Error: Required command '$NOTIF_CMD' not found"; exit 1; }

test $GIT_SYNC_DIRECTORY && cd $GIT_SYNC_DIRECTORY

while true; do
    $NOTIF_START
    ./git-sync.sh >> $LOGFILE 2>&1 || $NOTIF_ERROR
done
