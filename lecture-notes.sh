#!/bin/bash

PS4='+$(date -Ins) ${FUNCNAME[0]}:$LINENO: '
set -vx

source .env
EVENTS="close_write,move,delete,create,modify";
INCOMMAND="inotifywait -qr -e \"$EVENTS\" --exclude \"\.git\" \"$LECTURE_NOTES_DIRECTORY\" --format \"%w%f %e\""

EVENTS2="modify";
INCOMMAND2="inotifywait -qr -e \"$EVENTS2\" \"$LECTURE_NOTES_ORG_FILE_INDEX\" --format \"%w%f %e\""

echo "$INCOMMAND"
echo "$INCOMMAND2"
ORGZLY_DIR=$PWD

watch4LectureNotes () {
    while true; do
        eval $INCOMMAND
        if (( $? == 0 )); then
            echo "Detected LectureNotes event!"
            if ! ls $LECTURE_NOTES_ORG_LOCK_FILE &> /dev/null; then
                echo "Lock is free"
                cd $ORGZLY_DIR
                    python3 LectureNotesIndex.py 
                cd -
            fi
        fi
    done
}

watch4Org () {
    while true; do
        eval $INCOMMAND2
        echo "Detected Org event!"
        if ! ls $LECTURE_NOTES_ORG_LOCK_FILE &> /dev/null; then
            echo "Lock is free"
            cd $ORGZLY_DIR
                python3 LectureNotesRead.py 
            cd -
        fi
    done
}

watch4Org &
watch4LectureNotes &
