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

echo_date () {
    echo `date` $1
}


if [ "$(uname -m)" == "armv7l" ]; then
    TIMEOUT_PING="true"
else
    TIMEOUT_PING="(ssh -q $SYNC_HOST exit) &> /dev/null"
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

launch_orgzly_sync() {
    # Try to start the SyncService

    # Recommended intent: https://github.com/orgzly/orgzly-android/issues/231
    $AM broadcast -a com.orgzly.intent.action.SYNC_START com.orgzly/com.orgzly.android.ActionReceiver
    # This should trigger an SYNC_IN_PROGRESS notifications and the while loop below shouldn't be necessary

    while ( ! eval $SYNC_IN_PROGRESS ); do
        sleep 1
        echo `date +'%Y-%m-%d %H:%M:%S retrying...'`
        $AM start com.orgzly/com.orgzly.android.ui.main.MainActivity -W 
        $AM broadcast -a com.orgzly.intent.action.SYNC_START com.orgzly/com.orgzly.android.ActionReceiver
    done

    echo `date +'%Y-%m-%d %H:%M:%S success!'`  
}


git_add_commit_push() {
    git add .
    git commit -m "autocommit `git config user.name`@`date +'%Y-%m-%d %H:%M:%S'`"
    # TODO commit only once, get --name-only information from another source
    git commit -m "autocommit $(git log -n 1 --pretty=format:"%an@%ci" --name-only)" --amend
    git push || git pull && git push
    check_conflict "$?"
}


if is_command termux-info; then
    # We are on an Android device

    AM="am" # termux activity manager
    NOTIF_CMD="termux-notification"
    NOTIF_LIST="termux-notification-list"
    # Detect if there is an orgzly sync in progress
    # id 4 comes from:
    # https://github.com/orgzly/orgzly-android/blob/master/app/src/main/java/com/orgzly/android/ui/notifications/Notifications.java
    SYNC_IN_PROGRESS='$NOTIF_LIST | grep "|com.orgzly|4|" > /dev/null'
    # Detect if syncthing is not running
    # Likewise, id 4 comes from:
    # https://github.com/syncthing/syncthing-android/blob/master/app/src/main/java/com/nutomic/syncthingandroid/service/NotificationHandler.java
    SYNCTHING_NOT_RUNNING='$NOTIF_LIST | grep "|com.nutomic.syncthingandroid|4|" > /dev/null'
    NOTIF_CONFLICT="$NOTIF_CMD -t git-sync -c conflict --id sync-conflict --ongoing"
    NOTIF_LOST_CONNECTION="$NOTIF_CMD -t git-sync -c lost_connection --id lost-connection --ongoing"
    orgzly_check_and_sync() {
        if ! eval $SYNC_IN_PROGRESS; then
            # Only sync if there is not a sync in progress
            launch_orgzly_sync
        else
            # Cancel ongoing sync and launch a new sync
            $AM stopservice -n com.orgzly/com.orgzly.android.sync.SyncService
            launch_orgzly_sync
        fi
    }
elif [ "$(uname -m)" == "armv7l" ]; then
    # We are on a Raspberry Pi 4

    AM="true" # Disable command
    NOTIF_LIST="true" # Disable command
    SYNCTHING_NOT_RUNNING="false" # Disable command
    NOTIF_CMD=echo_date
    NOTIF_CONFLICT="$NOTIF_CMD git-sync conflict"
    NOTIF_LOST_CONNECTION="$NOTIF_CMD git-sync lost_connection"
    orgzly_check_and_sync () { 
        true 
    }
else
    # We are on a desktop environment

    AM="true" # Disable command
    NOTIF_LIST="true" # Disable command
    SYNCTHING_NOT_RUNNING="false" # Disable command
    NOTIF_CMD="notify-send"
    NOTIF_CONFLICT="$NOTIF_CMD git-sync conflict -t 0"
    RETRY_SECONDS=10
    NOTIF_LOST_CONNECTION="$NOTIF_CMD git-sync lost_connection -t $(($RETRY_SECONDS*1000))"
    orgzly_check_and_sync () {
        true
        
    }
fi

INW="inotifywait";
EVENTS="close_write,move,delete,create";
INCOMMAND="\"$INW\" -qr -e \"$EVENTS\" --exclude \"\.git\" \"$ORG_DIRECTORY\""
INNEWFILE="\"$INW\" -qr -e \"close_write,create\" --exclude \"\.git\" \"$ORG_DIRECTORY\""

for cmd in "git" "$INW" "timeout" "$AM" "$NOTIF_CMD" "$NOTIF_LIST"; do
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
        else
            # This is the behavior by default on Raspberry Pi and desktop environments
            # When syncthing is enabled, run frequently
            echo "Syncthing is running! Going into frequent mode..."
            RETRY_SECONDS=10
            WATCH_SECONDS=10
            CONFIRM_SECONDS=60
        fi

        # Wait until there's either a file change or WATCH_SECONDS, whichever is first
        eval "timeout $WATCH_SECONDS $INCOMMAND" || true
        PULL_RESULT=$(git pull) || check_conflict "$?"
        echo $PULL_RESULT
        if [ "$PULL_RESULT" !=  "Already up to date." ]; then
            ## This code is skipped unless we are in an Android device
            orgzly_check_and_sync
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
