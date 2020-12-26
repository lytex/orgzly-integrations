#!/data/data/com.termux/files/usr/bin/bash

set -e

source .env

update_clock_goto_notification() {

    count=$(grep -Pr 'CLOCK:[ ]+\[[0-9]{4}-[0-9]{2}-[0-9]{2} [^\[\]]{2,4} [0-9]{2}:[0-9]{2}\](?!--)' *.org | wc -l)
    if (($count != 1)); then
        termux-notification -t "multiple clocks detected! delete unused clocks and restart"
        exit 1
    fi

    current=$(grep -Pr 'CLOCK:[ ]+\[[0-9]{4}-[0-9]{2}-[0-9]{2} [^\[\]]{2,4} [0-9]{2}:[0-9]{2}\](?!--)')

    goto_clocked=am start -a android.intent.action.MAIN -n com.orgzly/com.orgzly.android.ui.main.MainActivity \
        --es "com.orgzly.intent.extra.QUERY_STRING" "$current" --activity-clear-task

    
    termux-notification -t current_clock --id current_clock --ongoing \
        --button1 goto-clock --button1-action "$goto_clocked"


}

INCOMMAND="inotifywait -qr -e close_write,move,delete,create --exclude \"\.git\" \"$ORG_DIRECTORY\""

while true; do
    $INCOMMAND
    update_clock_goto_notification
done