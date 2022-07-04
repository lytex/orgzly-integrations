#!/usr/bin/env bash

source .env

EVENTS="delete,create";
INCOMMAND="inotifywait -qr -e \"$EVENTS\" --exclude \"\.git\" \"$LECTURE_NOTES_DIRECTORY\" --format \"%w%f %e\""

while true; do
    eval $INCOMMAND
    python3 make_index.py
done
