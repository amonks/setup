#!/usr/bin/env fish

cd ~/git/amonks/monks.co/apps/reddit     ; or exit 1
eval (direnv export fish)      ; or exit 1
go run . update               ; or exit 1

