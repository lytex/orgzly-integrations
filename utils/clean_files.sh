#!/bin/bash
# echo files not including org/txt
for file in $(git ls-tree -r master --name-only | grep -v "[o|t][r|x][g|t]"); do echo "$file"; done 

# remove pdf files (run after gitignoring them!)
for file in $(git ls-tree -r master --name-only | grep pdf); do git rm --cached "$file"; done 