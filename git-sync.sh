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

if [ is_command termux_info ]; then
    AM="am" # termux activity manager
    NOTIF_CMD="termux-notification"
    NOTIF_CONFLICT="$NOTIF_CMD -c 'sync conflict!' --id 'sync-conflict'"
else
    AM="true" # Disable command
    # TODO Configure with notify-send
    NOTIF_CMD="true"
    NOTIF_CONFLICT="true"

INW="inotifywait";
EVENTS="close_write,move,delete,create";
INCOMMAND="\"$INW\" -qr -e \"$EVENTS\" --exclude \"\.git\" \"$ORG_DIRECTORY\""

for cmd in "git" "$INW" "timeout" "$AM" "$NOTIF_CMD"; do
    is_command "$cmd" || { stderr "Error: Required command '$cmd' not found"; exit 1; }
done

cd "$ORG_DIRECTORY"
echo -e "*\n**\n!*.org\n!.gitignore" > .gitignore
echo "$INCOMMAND"

while true; do
    eval "timeout 600 $INCOMMAND" || true
    git pull || $NOTIF_CONFLICT
    sleep 5
    STATUS=$(git status -s)
    if [ -n "$STATUS" ]; then
        echo "$STATUS"
        echo "commit!"
        git add .
        git commit -m "autocommit `git config user.name`@`date +'%Y-%m-%d %H:%M:%S'`"
        git push origin || $NOTIF_CONFLICT
        $AM startservice -a android.intent.action.MAIN -n com.orgzly/com.orgzly.android.sync.SyncService
    fi
done
