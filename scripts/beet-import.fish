#!/usr/bin/env fish

if test "$machine_name" != "thor"
	echo "must run on thor"
	exit 1
end


set import_flags "-l beet-import.log"
if contains -- --quiet $argv
	set import_flags "-ql beet-import.log"
end

set flac_path ~/whatbox/files/flac

set list_file (mktemp)
exa --sort newest --reverse $flac_path > $list_file
nvim $list_file
set albums
for album in (cat $list_file)
	set -a albums "$flac_path/$album"
end
rm $list_file

if test (count $albums) -eq "0"
	echo "nothing to do"
	exit 0
end

echo importing (count $albums) albums
beet import $import_flags $albums

and ~/scripts/beet-convert-mp3s.fish
and sudo service forked-daapd restart

