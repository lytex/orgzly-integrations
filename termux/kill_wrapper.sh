#!/data/data/com.termux/files/usr/bin/bash

killall wrapper.sh
killall git-sync.sh
termux-wake-unlock

termux-notification-remove sync-conflict
termux-notification-remove lost-connection
termux-notification-remove error
