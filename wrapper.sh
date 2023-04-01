#!/bin/bash

stderr () {
    echo "$1" >&2
}

echo_date () {
    echo `date` $1
}

export LOGFILE="$HOME/git-sync.log"

if command -v "termux-info" &>/dev/null ; then
    NOTIF_CMD="termux-notification"
    NOTIF_ERROR="$NOTIF_CMD -t git-sync -c ERROR --id error --ongoing"
    NOTIF_START="$NOTIF_CMD -t git-sync_started"
elif [ "$(uname -m)" == "aarch64" ]; then
    NOTIF_CMD=echo_date
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
    # Sometimes notifications take some time (minutes) when restarting the phone
    # To avoid blocking git-sync, spawn a new process
    $NOTIF_START &
    ./git-sync.sh >> $LOGFILE 2>&1 || ($NOTIF_ERROR &)
done
