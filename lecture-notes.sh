#!/bin/bash

source .env
cd "$LECTURE_NOTES_DIRECTORY"
EVENTS="close_write,move,delete,create";
INCOMMAND="inotifywait -qr -e \"$EVENTS\" --exclude \"\.git\" \"$LECTURE_NOTES_DIRECTORY\" --format \"%w%f\""
while true; do
    eval $INCOMMAND
    python3 /home/pi/orgzly-integrations/LectureNotesIndex.py 
done
