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

if [ "$(uname -m)" == "armv7l" ]; then
    TIMEOUT_PING="true"
else
    TIMEOUT_PING="(ssh -q $SYNC_HOST exit) &> /dev/null"
fi


if is_command termux-info; then
    # Mobile phone
    AM="am" # termux activity manager
    NOTIF_CMD="termux-notification"
    # Detect if there is an orgzly sync in progress
    # id 4 comes from:
    # https://github.com/orgzly/orgzly-android/blob/master/app/src/main/java/com/orgzly/android/ui/notifications/Notifications.java
    SYNC_IN_PROGRESS='termux-notification-list | grep "|com.orgzly|4|" > /dev/null'
    # Detect if syncthing is not running
    # Likewise, id 4 comes from:
    # https://github.com/syncthing/syncthing-android/blob/master/app/src/main/java/com/nutomic/syncthingandroid/service/NotificationHandler.java
    SYNCTHING_NOT_RUNNING='termux-notification-list | grep "|com.nutomic.syncthingandroid|4|" > /dev/null'
    NOTIF_LIST="termux-notification-list"
    NOTIF_CONFLICT="$NOTIF_CMD -t git-sync -c conflict --id sync-conflict --ongoing"
    NOTIF_LOST_CONNECTION="$NOTIF_CMD -t git-sync -c lost_connection --id lost-connection --ongoing"
    NOTIF_SYNC_SERVICE_FAILED="$NOTIF_CMD -t start-sync-service-manually"
elif [ "$(uname -m)" == "armv7l" ]; then
    ## RaspberryPi 4
    AM="true" # Disable command
    NOTIF_CMD="echo"
    SYNC_IN_PROGRESS='false' # Disable command
    SYNCTHING_NOT_RUNNING="false" # Disable command
    NOTIF_LIST="true" # Disable command
    NOTIF_CONFLICT="$NOTIF_CMD git-sync conflict"
    NOTIF_LOST_CONNECTION="$NOTIF_CMD git-sync lost_connection"
    NOTIF_SYNC_SERVICE_FAILED="true"
else
    # Regular Linux
    AM="true" # Disable command
    NOTIF_CMD="notify-send"
    SYNC_IN_PROGRESS='false' # Disable command
    SYNCTHING_NOT_RUNNING="false" # Disable command
    NOTIF_LIST="true" # Disable command
    NOTIF_CONFLICT="$NOTIF_CMD git-sync conflict -t 0"
    RETRY_SECONDS=10
    NOTIF_LOST_CONNECTION="$NOTIF_CMD git-sync lost_connection -t $(($RETRY_SECONDS*1000))"
    NOTIF_SYNC_SERVICE_FAILED="true"
fi

check_conflict() {
    if (( $1 != 0 )); then
        # Either there is a merge conflict or connection has been lost
        # If TIMEOUT_PING works and there are some uncommited files (possibly because of a conflict),
        # then, we assume it's a merge conflict, otherwise, we assume connection has been lost
        # TODO grep $1 against something like "automerge failed" (see git pull when there is a merge conflict)
        # Lost of connection may be notified as false conflicts
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
        if  eval $SYNCTHING_NOT_RUNNING; then
            # When syncthing is disabled, we assume the user wants to
            # save battery
            echo "Syncthing not running! Going into battery saving mode..."
            RETRY_SECONDS=300
            WATCH_SECONDS=300
            CONFIRM_SECONDS=60
            SLEEP_SYNC_IN_PROGRESS=3
        else
            # When syncthing is enabled, run frequently
            echo "Syncthing is running! Going into frequent mode..."
            RETRY_SECONDS=10
            WATCH_SECONDS=10
            CONFIRM_SECONDS=60
            SLEEP_SYNC_IN_PROGRESS=3
        fi

        # Wait until there's either a file change or WATCH_SECONDS, whichever is first
        eval "timeout $WATCH_SECONDS $INCOMMAND" || true
        PULL_RESULT=$(git pull) || check_conflict "$?"
        echo $PULL_RESULT
        if [ "$PULL_RESULT" !=  "Already up to date." ]; then
            if ! eval $SYNC_IN_PROGRESS; then
                # Only sync if there is not a sync in progress
                $AM startservice -n com.orgzly/com.orgzly.android.sync.SyncService
                sleep 1
                # If there is no notification, notify the user
                ( ! eval $SYNC_IN_PROGRESS ) &&  $AM start -n com.orgzly/com.orgzly.android.ui.main.MainActivity -W && 
 $AM startservice -n com.orgzly/com.orgzly.android.sync.SyncService && $NOTIF_SYNC_SERVICE_FAILED
            else
                # If there is a sync, retry each SLEEP_SYNC_IN_PROGRESS seconds
                while eval $SYNC_IN_PROGRESS; do
                    eval $SYNC_IN_PROGRESS && echo "SYNC_IN_PROGRESS detected" && sleep $SLEEP_SYNC_IN_PROGRESS
                done
                # Finally sync once the previous sync has ended
                $AM startservice -n com.orgzly/com.orgzly.android.sync.SyncService
                # If there is no notification, notify the user
                ( ! eval $SYNC_IN_PROGRESS ) &&  $AM start -n com.orgzly/com.orgzly.android.ui.main.MainActivity -W && 
 $AM startservice -n com.orgzly/com.orgzly.android.sync.SyncService && $NOTIF_SYNC_SERVICE_FAILED
            fi
        fi
        STATUS=$(git status -s)
        if [ -n "$STATUS" ]; then
            # There are local changes
            echo "$STATUS"
            # See fix_deletions.py to see why is this necessary
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
