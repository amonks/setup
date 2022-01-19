#!/usr/bin/env fish

cd ~/request

tmux split-window -hb 'emacs .'
yarn dev
