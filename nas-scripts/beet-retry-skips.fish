#!/usr/bin/env fish

set file "$HOME/beet-import.log"
set albums
for album in (cat $file | grep '^skip')
	set dir (echo $album | sed 's/^skip //')
	set -a albums "$dir"
end
echo importing (count $albums) albums
beet import $albums

