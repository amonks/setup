#!/usr/bin/env fish

if test "$machine_name" != "thor"
	echo "must run on thor"
	exit 1
end


set batchsize 5
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



# ========== do the thing ============

# if a line number was passed; skip the bookmark stuff and just
# handle that one line
if test -n "$argv[1]"
	set lineno "$argv[1]"
	set batch (cat $infile | tail -n +$lineno | head -n1)
	echo "$batch"
	if ! yes-or-no "import only this album"
		exit 1
	end
	beet import "$batch"
	exit $status
end


# build batch for import
set batch 
for alb in (get-next-batch)
	echo "  $alb"
	set -a batch "$alb"
end
echo importing (count $batch) albums


# actually do import
beet import $batch
or exit 1


# mark these albums as imported
for alb in $batch
	echo $alb >> $outfile
end
report-batch


# ring a bell
bell 10
