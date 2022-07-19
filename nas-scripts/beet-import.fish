#!/usr/bin/env fish

set list_file (mktemp)
exa --sort newest --reverse /mypool/data/mirror/whatbox/files/flac > $list_file
nvim $list_file
set albums
for album in (cat $list_file)
	set -a albums "/mypool/data/mirror/whatbox/files/flac/$album"
end
rm $list_file
echo importing (count $albums) albums
beet import -l beet-import.log $albums

~/nas-scripts/beet-convert-mp3s.fish

sudo service forked-daapd restart

