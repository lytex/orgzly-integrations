#!/bin/bash

source .env
EVENTS="close_write,move,delete,create,modify";
INCOMMAND="inotifywait -qr -e \"$EVENTS\" --exclude \"\.git\" \"$LECTURE_NOTES_DIRECTORY\" --format \"%w%f %e\" -t 5"

EVENTS2="modify";
INCOMMAND2="inotifywait -qr -e \"$EVENTS2\" \"$LECTURE_NOTES_ORG_FILE_INDEX\" --format \"%w%f %e\" -t 5"

echo "$INCOMMAND"
echo "$INCOMMAND2"
ORGZLY_DIR=$PWD

watch4LectureNotes () {
    eval $INCOMMAND
    if (( $? == 0 )); then
        echo "Detected LectureNotes event!"
        pushd $ORGZLY_DIR
            python3 LectureNotesIndex.py 
        popd
    fi
}

watch4Org () {
    eval $INCOMMAND2
    if (( $? == 0 )); then
        echo "Detected Org event!"
        pushd $ORGZLY_DIR
            python3 LectureNotesRead.py 
        popd
    fi
}
while true; do
    watch4LectureNotes
    watch4Org
done
