#!/usr/bin/env fish

cd ~/semistatic
tmux split-window -hb 'emacs .'
go version
