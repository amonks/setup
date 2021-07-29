#!/usr/bin/env fish

set list_file (mktemp)
exa --sort newest --reverse /mypool/data/mirror/whatbox/files/flac > $list_file
nvim $list_file
for album in (cat $list_file)
	beet import -ql ~/beet-import.log "/mypool/data/mirror/whatbox/files/flac/$album"
end
rm $list_file

