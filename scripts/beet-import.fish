#!/usr/bin/env fish

set flac_path /usr/home/ajm/mnt/whatbox/files/flac

if test "$machine_name" != "thor"
	echo "must run on thor"
	exit 1
end


set import_flags "-l" "beet-import.log"
if contains -- --quiet $argv
	set import_flags "-ql" "beet-import.log"
end

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

set total_albums (count $albums)
set batch_size 10
set current_index 1

echo "Importing $total_albums albums in batches of $batch_size..."

while test $current_index -le $total_albums
	set end_index (math min $current_index + $batch_size - 1, $total_albums)
	set current_batch $albums[$current_index..$end_index]
	
	echo "Processing batch $current_index to $end_index of $total_albums"
	beet import $import_flags $current_batch
	or exit 1
	
	set current_index (math $end_index + 1)
end

if ! contains -- --no-convert $argv
	echo "Done importing. Converting to mp3."
	~/scripts/beet-convert-mp3s.fish
end

