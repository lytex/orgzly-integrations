#!/bin/bash

if command -v "termux-info" &>/dev/null ; then
    NOTIF_CMD="termux-notification"
    NOTIF_ERROR="$NOTIF_CMD -t git-sync -c ERROR --id error --ongoing"
else
    NOTIF_CMD="notify-send"
    NOTIF_ERROR="$NOTIF_CMD git-sync ERROR -t 0"
fi

LOGFILE="$HOME/git-sync.log"
source git-sync.sh > $LOGFILE 2>&1 || $NOTIF_ERROR
