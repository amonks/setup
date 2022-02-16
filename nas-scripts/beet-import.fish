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
beet import $albums

exit 0

wait-for 10 beets to catch up
sudo service forked-daapd restart

wait-for 10 forked-daapd to catch up
echo "ok reconnect itunes now"

