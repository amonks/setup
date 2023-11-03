#!/usr/bin/env fish

rsync -ha --progress \
	--exclude ".zfs" \
	thor:/data/tank/music/mp3/ ~/Music/Library-v0

