#!/data/data/com.termux/files/usr/bin/bash

set -e
set -x

source .env

update_clock_goto_notification() {

    count=$(grep -Pr 'CLOCK:[ ]+\[[0-9]{4}-[0-9]{2}-[0-9]{2} [^\[\]]{2,4} [0-9]{2}:[0-9]{2}\](?!--)' **.org **/**.org | wc -l)
    if (($count > 1)); then
        termux-notification -t "multiple clocks detected! delete unused clocks and restart"
        exit 1
    fi

    # -h hides the filename
    current=$(grep -Phr 'CLOCK:[ ]+\[[0-9]{4}-[0-9]{2}-[0-9]{2} [^\[\]]{2,4} [0-9]{2}:[0-9]{2}\](?!--)' **.org **/**.org || echo $current)

    goto_clocked="am start -a android.intent.action.MAIN -n com.orgzly/com.orgzly.android.ui.main.MainActivity \
        --es \"com.orgzly.intent.extra.QUERY_STRING\" \"$current\" --activity-clear-task"

    
    termux-notification -t current_clock --id current_clock --ongoing --alert-once --priority max \
        --button1 goto-clock --button1-action "$goto_clocked"


}

INCOMMAND="inotifywait -qr -e close_write,move,create --exclude \.git $ORG_DIRECTORY"
cd $ORG_DIRECTORY

while true; do
    # inotifywait can exit 1, see man inotifywait -> EXIT STATUS
    $INCOMMAND || true
    update_clock_goto_notification
done