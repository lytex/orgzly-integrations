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

if is_command termux-info; then
    AM="am" # termux activity manager
    NOTIF_CMD="termux-notification"
    NOTIF_CONFLICT="$NOTIF_CMD -c 'sync conflict!' --id 'sync-conflict'"
else
    AM="true" # Disable command
    NOTIF_CMD="notify-send"
    NOTIF_CONFLICT="notify-send 'sync conflict! -t 0"
fi

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
    eval "timeout 10 $INCOMMAND" || true
    PULL_RESULT=$(git pull) || $NOTIF_CONFLICT
    echo $PULL_RESULT
    if [ "$PULL_RESULT" !=  "Already up to date." ]; then
        $AM startservice -a android.intent.action.MAIN -n com.orgzly/com.orgzly.android.sync.SyncService
    fi
    STATUS=$(git status -s)
    if [ -n "$STATUS" ]; then
        echo "$STATUS"
        echo "commit!"
        git add .
        git commit -m "autocommit `git config user.name`@`date +'%Y-%m-%d %H:%M:%S'`"
        # TODO commit only once, get --name-only information from another source
        git commit -m "autocommit $(git log -n 1 --pretty=format:"%an@%ci" --name-only)" --amend
        git push origin || $NOTIF_CONFLICT
        $AM startservice -a android.intent.action.MAIN -n com.orgzly/com.orgzly.android.sync.SyncService
    fi
done
