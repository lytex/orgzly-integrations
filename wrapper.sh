#!/bin/bash

if is_command termux-info; then
    NOTIF_CMD="termux-notification"
    NOTIF_ERROR="$NOTIF_CMD -t git-sync -c ERROR --id error --ongoing"
else
    NOTIF_CMD="notify-send"
    NOTIF_ERROR="$NOTIF_CMD git-sync ERROR -t 0"
fi

LOGFILE="~/git-sync.log"
./git-sync.sh > $LOGFILE 2>&1 || $NOTIF_ERROR
