#!/bin/bash

get_children() {
    if [ ! -z $1 ]; then
        ps -e -o pid,ppid  | grep $1 | grep -v "^ $1" | awk '{print $1}'
    fi
}

get_all_children() {
    children=$1
    while [ ! -z $children ]; do
        children=$(get_children $pid)
        echo $children
        for child in children; do
            children=$(get_all_children $child)
        done
    done
}

