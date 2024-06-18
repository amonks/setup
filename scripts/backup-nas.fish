#!/usr/bin/env fish

		# pv --progress --timer --eta --rate --bytes --size=(get-size $sendcmd) |
		# lzop |
		# mbuffer -q -s 128k -m 16M |


set lock_file /home/ajm/.backup.lock

set sshkey    '/home/ajm/.ssh/id_ed25519'
set sshhost   'root@57269.zfs.rsync.net'
set sshcmd    ssh -i $sshkey $sshhost

argparse 'latest' 'dryrun' 'devnull' 'fresh' 'dataset=' -- $argv
set dryrun    "$_flag_dryrun"
set norecv    "$_flag_devnull"
set fresh     "$_flag_fresh"
set latest    "$_flag_latest"
set dataset   "$_flag_dataset"

########################################################################
########################################################################
########################################################################

function sync --argument-names src dest
	if has-resume $dest
		if test -n "$fresh"
			echo "  -- aborting unfinished send"
			$sshcmd zfs receive -A $dest || return 1
			sync $src $dest || return 1
			return 0
		end
		echo "  -- resuming send"
		echo "  -- from: '$src'"
		echo "  -- to: '$dest'"
		send-interrupted $dest (get-resume $dest) || return 1
		sync $src $dest || return 1
		return 0
	end

	if remote-has $src
		set --local from (get-remote-latest $src)
		set --local to (get-local-latest $src)
		if test "$from" = "$to"
			echo "  -- nothing to do"
			return 0
		end

		echo "  -- sending range"
		echo "  -- from: '$src'"
		echo "  -- to: '$dest'"
		echo "  -- first: '$from'"
		echo "  -- last: '$to'"
		send-range $src $dest $from $to || return 1
		return 0
	end

	set --local snap (get-local-latest $src)
	echo "  -- sending snapshot"
	echo "  -- from: '$src'"
	echo "  -- to: '$dest'"
	echo "  -- snap: '$snap'"
	send-snap $src $dest $snap || return 1
	return 0
end

function send-range --argument-names src dest firstsnap lastsnap
	if test -z "$src" || test -z "$dest" || test -z "$firstsnap" || test -z "$lastsnap"
		echo "send-range expects 4 arguments"
		exit 1
	end

	send-with $dest -I $src@$firstsnap $src@$lastsnap
end

function send-interrupted --argument-names dest token
	if test -z "$dest" || test -z "$token"
		echo "send-interrupted expects 1 argument"
		exit 1
	end

	send-with $dest -t $token
end

function send-snap --argument-names src dest snap
	if test -z "$src" || test -z "$dest" || test -z "$snap"
		echo "send-snap expcets 3 arguments"
		exit 1
	end

	send-with $dest $src $snap
end

function send-with
	set --local target $argv[1]
	set --local sendargs $argv[2..-1]
	set --local sendcmd zfs send --raw $sendargs
	set --local remotepipe "mbuffer -q -s 128k -m16M | lzop -dfc | "
	set --local remotepipe ""
	set --local remotecmd "$remotepipe zfs receive -s -F $target"
	if test -n "$norecv"
		echo "  -- SENDING TO DEV NULL"
		set remotecmd "$remotepipe cat > /dev/null"
	end

	set --local size (get-size $sendcmd)
	echo "  -- size: $size"

	echo "  -- cmd: $sendcmd | $sshcmd \"$remotecmd\""
	if test -n "$dryrun"
		echo "  -- [dry run]"
		return 0
	end

	$sendcmd | $sshcmd "$remotecmd"
end

function get-size
	$argv --dryrun --verbose --parsable | tail -n1 | awk '{ print $2 }'
end

function get-local-latest --argument-names ds
	zfs list -t snapshot -o name -s creation -d1 $ds | tail -1 | cut -d'@' -f2
end

function remote-has --argument-names ds
	set latest (get-remote-latest $ds)
	if test -z $latest
		return 1
	end
end

function get-remote-latest --argument-names ds
	set --local localsnaps (zfs list -t snapshot -o name -s creation -d1 $ds 2>&1)
	set --local remotesnaps ($sshcmd "zfs list -t snapshot -o name -s creation -d1 $(string replace data/tank data1/thor/tank $ds)" 2>&1)
	if string match -q '*cannot open*' "$remotesnaps"
		echo "cannot open"
		return 1
	end

	for index in (seq (count $remotesnaps) 2)
		set --local snap (echo $remotesnaps[$index] | cut -d@ -f2)
		if echo $localsnaps | grep -q $snap
			echo $snap
			return 0
		end
	end
	return 1
end

function has-resume --argument-names ds
	set --local resume (get-resume $ds)
	if test "$resume" = "-"
		return 1
	end
	return 0
end

function get-resume --argument-names ds
	$sshcmd "zfs list -o receive_resume_token -S name -d1 $ds | tail -1"
end

function unlock_backup
	echo "---- unlock"
	rm $lock_file
end

function lock_backup
	if test -f $lock_file
		echo "There is already a backup in progress."
		exit 1
	end

	echo "---- lock"
	touch $lock_file
end

########################################################################
########################################################################
########################################################################

# with --latest, just print latest remote snap and return
if test -n "$latest"
	if ! test -n "$dataset"
		echo "must specify dataset with latest"
		exit 1
	end
	get-remote-latest $dataset
	exit 0
end

# perform sync
#

if test (whoami) != "root"
	echo must be root
	exit 1
end

lock_backup
trap unlock_backup INT

if test -n "$dataset"
	echo "---- sync $dataset"
	sync $dataset (string replace data/tank data1/thor/tank $dataset)
	if test $status -ne 0
		unlock_backup
		exit 1
	end
	exit 0
end

for ds in (zfs list -o name | grep tank)
	echo "---- sync $ds..."
	sync $ds (string replace data/tank data1/thor/tank $ds)
	if test $status -ne 0
		unlock_backup
		exit 1
	end
end

unlock_backup
exit 0

