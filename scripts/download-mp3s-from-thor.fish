#!/usr/bin/env fish

rsync -ha --progress \
	--checksum \
	--exclude ".zfs" \
	--delete \
	thor:/data/tank/music/mp3/ ~/Music/Library-v0

