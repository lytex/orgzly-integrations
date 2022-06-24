#!/usr/bin/env bash
set -x

if ! ls .git; then
    cd ..
fi

DEST="$HOME/.local/share/orgzly-integrations/"
SYSTEMD_FOLDER="$HOME/.config/systemd/user"

mkdir -p "$DEST"
mkdir -p "$SYSTEMD_FOLDER"

cp git-sync.sh "$DEST"
cp .env $HOME
cp .lnignore $HOME
cp LectureNotesIndex.py "$DEST"
cp LectureNotesRead.py "$DEST"
cp lecture-notes.sh "$DEST"

cp systemd/gitsync.service "$SYSTEMD_FOLDER"
cp systemd/lecturenotes.service "$SYSTEMD_FOLDER"
cp systemd/makeindex.service "$SYSTEMD_FOLDER"

systemctl --user daemon-reload
