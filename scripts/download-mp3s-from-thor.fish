#!/usr/bin/env fish

rsync -ha --progress \
	--exclude ".zfs" \
	--delete \
	thor:/data/tank/music/mp3/ ~/Music/Library-v0

