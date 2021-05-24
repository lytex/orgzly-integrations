#!/data/data/com.termux/files/usr/bin/bash

cd /data/data/com.termux/files/home/orgzly-integrations/
# Launch git-sync if it's now already running
(ps -e | grep wrapper.sh) || ./wrapper.sh
source .env
touch "$ORGZLY_FILE_INDEX"