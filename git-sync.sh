#!/bin/bash
# Modified from https://jakemccrary.com/blog/2020/02/25/auto-syncing-a-git-repository/

set -e
PS4='+${LINENO}:'
set -vx

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

declare -i PUSH_CODE
declare PUSH_RESULT
declare -i PULL_CODE
declare PULL_RESULT
MAX_RETRY_CONNECTION=5 # Number of times to retry connection


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
        eval "$TIMEOUT_PING" && [ -n "$(git status -s)" ] && $NOTIF_CONFLICT || $NOTIF_LOST_CONNECTION
        echo $1
    fi
}

launch_orgzly_sync() {
    # Try to start the SyncService

    # Recommended intent: https://github.com/orgzly/orgzly-android/issues/231
    $AM broadcast -a com.orgzly.intent.action.SYNC_START com.orgzly/com.orgzly.android.ActionReceiver

    # This should trigger an SYNC_IN_PROGRESS notifications and the while loop below shouldn't be necessary
    # Uncomment if needed again
    # while ( ! eval $SYNC_IN_PROGRESS ); do
    #     sleep 1
    #     echo `date +'%Y-%m-%d %H:%M:%S retrying...'`
    #     $AM start com.orgzly/com.orgzly.android.ui.main.MainActivity -W 
    #     $AM broadcast -a com.orgzly.intent.action.SYNC_START com.orgzly/com.orgzly.android.ActionReceiver
    # done

    # echo `date +'%Y-%m-%d %H:%M:%S success!'`  
}

wait_for_connection () {
    # Loop until there is connectivity, or try == $MAX_RETRY_CONNECTION
    try=0
    while (! eval "$TIMEOUT_PING") & (($try < $MAX_RETRY_CONNECTION)); do
        $NOTIF_LOST_CONNECTION
        sleep $SYNC_WAIT_SECONDS
        $((try++))
    done
}

git_add_commit() {
    # To avoid weird commits where files are missing because orgzly is in the middle of a Sync,
    # add_commit only when this Sync has finished
    try=0
    while ((try < 3)); do
        echo "Retrying for the $try time" >> "$LOGFILE"
        while eval "$SYNC_IN_PROGRESS"; do
            sleep "$SYNC_WAIT_SECONDS"
            echo "Sync in progress..." >> "$LOGFILE"
        done
        echo "git add commit" >> "$LOGFILE"
        # when there's another process locking the index, add fails with:
        # fatal: Unable to create '<path to repo>/.git/index.lock': File exists.
        # Add a || true so that always returns zero and the script doesn't exit
        git add . || true
        # git commit fails if the repo it there are not any changes
        # Also add || true (see above)
        user_date="$(git config user.name)@$(date +'%Y-%m-%d %H:%M:%S')"
        changed_files=$(git status -s | awk '{$1=""; print $0}' | tr -d '\n')
        git commit -m "autocommit $user_date $changed_files" || true
        echo $((try++)) > /dev/null
    done
}

git_pull() {

    PULL_CODE=0 # Establish default value, only replace if its different from 0
    echo "git pull" >> "$LOGFILE"
    PULL_RESULT=$(git pull) || PULL_CODE=${PULL_CODE:-$(check_conflict "$?")}
    echo $PULL_RESULT >> "$LOGFILE"
    if [ "$PULL_RESULT" !=  "Already up to date." ]; then
        ## This code is skipped unless we are in an Android device
        orgzly_check_and_sync
    fi
}

git_push () {

    echo "git push" >> "$LOGFILE"
    PUSH_CODE=0 # Establish default value, only replace if its different from 0
    PUSH_RESULT=$(git push 2>&1) || PUSH_CODE=${PUSH_CODE:-$(check_conflict "$?")}
    echo $PUSH_RESULT >> "$LOGFILE"
}

git-sync-polling() {
    while true; do
        while eval "$TIMEOUT_PING"; do # Ensure connectivity
            # if there are new commits, start the process
            if [ -n "$(git fetch 2>&1)" ]; then
                echo "New commits" >> "$LOGFILE"
                # add commit always, even if there is nothing new
                # thus, you can git pull without failing
                # merge conflicts may be generated, but the command executes cleanly
                git_add_commit
                git_pull
                if (( $PULL_CODE == 0 )); then
                    continue
                else
                    wait_for_connection
                    git_pull
                fi
                git_add_commit # In case there is a merge conflict
            fi
            # Redundant add/commit, sometimes it's necessary even though it shouldn't:
            git_add_commit
            git_push
            sleep $POLLING_SECONDS
        done
    $NOTIF_LOST_CONNECTION
    sleep $RETRY_SECONDS
done 
}




if is_command termux-info; then
    # We are on an Android device

    termux-wake-lock # Do not kill this shell
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
    NOTIF_CONFLICT="$NOTIF_CMD --alert-once -t git-sync -c conflict --id sync-conflict --ongoing"
    NOTIF_LOST_CONNECTION="$NOTIF_CMD --alert-once -t git-sync -c lost_connection --id lost-connection --ongoing"
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
    SYNC_IN_PROGRESS="false" # Disable command
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
    SYNC_IN_PROGRESS="false" # Disable command
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

cd "$ORG_DIRECTORY"
echo "$INCOMMAND"

# If connection fails at the very first loop, RETRY_SECONDS has to be set
# Otherwise sleep $RETRY_SECONDS fails
RETRY_SECONDS=10
POLLING_SECONDS=10
SYNC_WAIT_SECONDS=10

echo "Starting git-sync-polling" >> "$LOGFILE"
git-sync-polling &

while true; do
    while eval "$TIMEOUT_PING"; do # Ensure connectivity
        if  eval $SYNCTHING_NOT_RUNNING; then
            # When syncthing is disabled, we assume the user wants to
            # save battery
            echo "Syncthing not running! Going into battery saving mode..."
            RETRY_SECONDS=300
            POLLING_SECONDS=300
            SYNC_WAIT_SECONDS=60
        else
            # This is the behavior by default on Raspberry Pi and desktop environments
            # When syncthing is enabled, run frequently
            echo "Syncthing is running! Going into frequent mode..."
            RETRY_SECONDS=15
            POLLING_SECONDS=60
            SYNC_WAIT_SECONDS=10
        fi

        # Wait until there's a file change matching .org files
        files=$(eval $INCOMMAND | grep -i "\.org$") || true
        if [ -n "$files" ]; then
            git_add_commit
            git_push
            if (( $PUSH_CODE == 0 )); then
                continue
            else
                wait_for_connection
                git_push
                git_pull
                if (( $PULL_CODE == 0 )); then
                    continue
                else
                    wait_for_connection
                    git_pull
                    git push
                fi
            fi
        fi
    done
    $NOTIF_LOST_CONNECTION
    sleep $RETRY_SECONDS
done 
