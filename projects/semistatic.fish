#!/usr/bin/env fish

set WORKDIR ~/semistatic

tmux split-window -hb 'emacs .'
go version
