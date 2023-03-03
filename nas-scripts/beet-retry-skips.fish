#!/usr/bin/env fish

set batchsize 10
set infile "$HOME/beet-skips.log"
set outfile "$HOME/beet-corrected.log"
set bookmarkfile "$HOME/beet-retry-bookmark.stamp"
set todo (cat $infile | wc -l | string trim)

function set-bookmark --argument-names value
	echo $value > $bookmarkfile
end

function get-bookmark
	cat $bookmarkfile | string trim
end

function report-batch
	set --local bookmark (get-bookmark)
	set --local new_bookmark (math $bookmark + $batchsize)
	echo "moving bookmark from $bookmark to $new_bookmark"
	set-bookmark $new_bookmark
end

function get-next-batch
	cat $infile | tail -n +(math (get-bookmark) + 1) | head -n$batchsize
end

if ! test -f $bookmarkfile
	set-bookmark 0
end

while test (get-bookmark) -lt $todo
	set batch 
	for alb in (get-next-batch)
		echo "  $alb"
		set -a batch "$alb"
	end
	echo importing (count $batch) albums

	beet import $batch
	or exit 1

	for alb in $batch
		echo $alb >> $outfile
	end

	beet convert
	report-batch
end
