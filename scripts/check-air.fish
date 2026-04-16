#!/usr/bin/env fish

cd ~/git/amonks/monks.co/
eval "$(direnv export fish)"
cd apps/air
MONKS_ROOT=~/git/amonks/monks.co go run .
