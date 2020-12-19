#!/bin/bash

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

LOGFILE="$HOME/git-sync.log"
source .env

cd $GIT_SYNC_DIRECTORY
while true;
    $NOTIF_CMD "git-sync started"
    ./git-sync.sh >> $LOGFILE 2>&1 || $NOTIF_ERROR
    $NOTIF_CMD "git-sync restarted"
done
