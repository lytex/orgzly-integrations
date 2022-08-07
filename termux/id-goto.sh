#!/data/data/com.termux/files/usr/bin/bash

set -e
set -x

source ../.env

cd $ORG_DIRECTORY

query=$(termux-dialog | jq .text) # query already has quotes

am start -a android.intent.action.MAIN -n com.orgzly/com.orgzly.android.ui.main.MainActivity \
    --es "com.orgzly.intent.extra.QUERY_STRING" $query --activity-clear-task
