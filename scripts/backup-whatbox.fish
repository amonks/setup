#!/usr/bin/env fish

rsync \
	--archive \
	--human-readable \
	--delete \
	--progress \
	--exclude .zfs \
	--exclude .config/transmission-daemon/resume \
	--exclude files/wheel \
	whatbox:/home/ajm/ \
	/data/dmz/whatbox

