#!/usr/bin/env fish

cd ~/git/amonks/monks.co/
source .envrc
cd apps/air
MONKS_ROOT=~/git/amonks/monks.co go run .
