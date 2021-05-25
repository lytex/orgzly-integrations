#!/data/data/com.termux/files/usr/bin/bash

cd /data/data/com.termux/files/home/orgzly-integrations/
# Launch git-sync if it's now already running
(ps -e | grep wrapper.sh) || (setsid ./wrapper.sh &)
while ! (ps -e | grep "inotifywait"); do sleep 1; done # Wait for inotifywait
source .env
touch "$ORGZLY_FILE_INDEX"