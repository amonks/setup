#!/usr/bin/env fish

set batchsize 20
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
	set-bookmark (math (get-bookmark) + $batchsize)
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
		set -a batch "$alb"
	end
	beet import $batch
	for alb in $batch
		echo $alb >> $outfile
	end
	report-batch
end
