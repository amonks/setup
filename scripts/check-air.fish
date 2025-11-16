#!/usr/bin/env fish

cd ~/monks.co/
source .envrc
cd apps/air
MONKS_ROOT=~/monks.co go run .
