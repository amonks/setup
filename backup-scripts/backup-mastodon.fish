#!/usr/bin/env fish

cd ~/mastodon-archiver
and eval "$(direnv export fish)"
and ./import-posts.fish

