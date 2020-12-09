#!/bin/bash
# Modified from https://jakemccrary.com/blog/2020/02/25/auto-syncing-a-git-repository/

set -e

source .env # Get ORG_DIRECTORY environment var from one centralized file

stderr () {
    echo "$1" >&2
}

is_command() {
    command -v "$1" &>/dev/null
}

SYNC_HOST="lytex_space_git"
RETRY_SECONDS=10
WATCH_SECONDS=10
CONFIRM_SECONDS=60
if [ "$(uname -m)" == "armv7l" ]; then
    TIMEOUT_PING="true"
else
    TIMEOUT_PING="(ssh -q $SYNC_HOST exit) &> /dev/null"


if is_command termux-info; then
    AM="am" # termux activity manager
    NOTIF_CMD="termux-notification"
    NOTIF_CONFLICT="$NOTIF_CMD -t git-sync -c conflict --id sync-conflict --ongoing"
    NOTIF_LOST_CONNECTION="$NOTIF_CMD -t git-sync -c lost_connection --id lost-connection --ongoing"
elif [ "$(uname -m)" == "armv7l" ]; then
    AM="true" # Disable command
    NOTIF_CMD="echo"
    NOTIF_CONFLICT="$NOTIF_CMD git-sync conflict"
    NOTIF_LOST_CONNECTION="$NOTIF_CMD git-sync lost_connection"
else
    AM="true" # Disable command
    NOTIF_CMD="notify-send"
    NOTIF_CONFLICT="$NOTIF_CMD git-sync conflict -t 0"
    NOTIF_LOST_CONNECTION="$NOTIF_CMD git-sync lost_connection -t $(($RETRY_SECONDS*1000))"
fi

check_conflict() {
    if (( $1 != 0 )); then
        # Either there is a merge conflict or connection has been lost
        # If TIMEOUT_PING works and there are some uncommited files (possibly because of a conflict),
        # then, we assume it's a merge conflict, otherwise, we assume connection has been lost
        eval "$TIMEOUT_PING" && [ -n "(git status -s)" ] && $NOTIF_CONFLICT || $NOTIF_LOST_CONNECTION
    fi
}

git_add_commit_push() {
    git add .
    git commit -m "autocommit `git config user.name`@`date +'%Y-%m-%d %H:%M:%S'`"
    # TODO commit only once, get --name-only information from another source
    git commit -m "autocommit $(git log -n 1 --pretty=format:"%an@%ci" --name-only)" --amend
    git push || git pull && git push
    check_conflict "$?"
}

INW="inotifywait";
EVENTS="close_write,move,delete,create";
INCOMMAND="\"$INW\" -qr -e \"$EVENTS\" --exclude \"\.git\" \"$ORG_DIRECTORY\""
INNEWFILE="\"$INW\" -qr -e \"close_write,create\" --exclude \"\.git\" \"$ORG_DIRECTORY\""

for cmd in "git" "$INW" "timeout" "$AM" "$NOTIF_CMD"; do
    is_command "$cmd" || { stderr "Error: Required command '$cmd' not found"; exit 1; }
done

OLD_DIR=$(pwd)
cd "$ORG_DIRECTORY"
echo "$INCOMMAND"

while true; do
    while eval "$TIMEOUT_PING"; do # Ensure connectivity
        eval "timeout $WATCH_SECONDS $INCOMMAND" || true
        PULL_RESULT=$(git pull) || check_conflict "$?"
        echo $PULL_RESULT
        if [ "$PULL_RESULT" !=  "Already up to date." ]; then
            $AM startservice -a android.intent.action.MAIN -n com.orgzly/com.orgzly.android.sync.SyncService
        fi
        STATUS=$(git status -s)
        if [ -n "$STATUS" ]; then
            echo "$STATUS"
            deleted_status=0
            python3 "$OLD_DIR/fix_deletions.py" || deleted_status=$?
            echo $deleted_status $deleted_files
            if (($deleted_status == 0)); then
                echo "commit!"
                git_add_commit_push
            else
                echo "file deleted! waiting $CONFIRM_SECONDS or until creation of new file"
                eval "timeout $CONFIRM_SECONDS $INNEWFILE" || true
                git_add_commit_push
            fi
        fi
    done
    $NOTIF_LOST_CONNECTION
    sleep $RETRY_SECONDS
done 
