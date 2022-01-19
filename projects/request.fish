#!/usr/bin/env fish

set WORKDIR ~/request

tmux split-window -hb 'emacs .'
yarn dev
