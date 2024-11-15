#!/usr/bin/env fish

set lock_file /home/ajm/.backup.lock

set sshkey    '/home/ajm/.ssh/id_ed25519'
set sshhost   'root@57269.zfs.rsync.net'
set sshcmd    ssh -i $sshkey $sshhost

argparse 'latest' 'dryrun' 'devnull' 'fresh' 'new' 'dataset=' -- $argv
set new       "$_flag_new"
set dryrun    "$_flag_dryrun"
set norecv    "$_flag_devnull"
set fresh     "$_flag_fresh"
set latest    "$_flag_latest"
set dataset   "$_flag_dataset"

########################################################################
########################################################################
########################################################################

function sync --argument-names ds
	set --local resume (get-resume $ds)
	if test -z "$new"
		if test -n "$fresh" || test "$resume" = "stale"
			echo "  -- aborting unfinished send"
			$sshcmd zfs receive -A (dest $ds) || return 1
			sync $ds || return 1
			return 0
		else if test $resume != "none"
			echo "  -- resuming send"
			send-interrupted $ds $resume || return 1
			sync $ds || return 1
			return 0
		end
	else
		echo "  -- new send"
	end

	set --local create false
	if remote-has $ds
		set --local from (get-remote-latest $ds)
		set --local to (get-local-latest $ds)
		if test "$from" = "$to"
			echo "  -- nothing to do"
			return 0
		end

		echo "  -- sending range"
		echo "  -- first: '$from'"
		echo "  -- last: '$to'"
		send-range $ds $from $to || return 1
		return 0
	else
		set create true
	end

	set --local snap (get-local-latest $ds)
	echo "  -- sending snapshot"
	echo "  -- snap: '$snap'"
	send-snap $ds $snap $create || return 1
	return 0
end

function send-range --argument-names ds firstsnap lastsnap
	if test -z "$ds" || test -z "$firstsnap" || test -z "$lastsnap"
		echo "send-range expects 3 arguments"
		exit 1
	end

	send-with $ds -I $ds@$firstsnap $ds@$lastsnap
end

function send-interrupted --argument-names ds token
	if test -z "$ds" || test -z "$token"
		echo "send-interrupted expects 2 arguments"
		exit 1
	end

	send-with $ds -t $token
end

function send-snap --argument-names ds snap create
	if test -z "$ds" || test -z "$snap" || test -z "$create"
		echo "send-snap expects 3 arguments"
		exit 1
	end

	if test $create = true
		send-with new $ds $ds@$snap
	else
		send-with $ds $ds $snap
	end
end

function send-with
	set --local receiveflag "-F"
	if test $argv[1] = new
		set receiveflag ""
		set --erase argv[1]
	end

	set --local ds $argv[1]
	set --local target (dest $ds)
	set --local sendargs $argv[2..-1]
	set --local sendcmd zfs send --raw $sendargs
	set --local remotecmd "zfs receive -s $receiveflag $target"
	if test -n "$norecv"
		echo "  -- SENDING TO DEV NULL"
		set remotecmd "cat > /dev/null"
	end

	set --local size (get-size $sendcmd | gnumfmt --to=iec)b
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
	else if test "$latest" = "cannot open"
		return 1
	else
		return 0
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

function dest --argument-names src
	string replace data/tank data1/thor/tank $src
end

function get-resume --argument-names ds
	set --local target (dest $ds)
	set --local resume ($sshcmd "zfs list -o receive_resume_token -S name -d1 $target | tail -1" 2>&1)
	if test $resume = '-'
		echo "none"
		return 0
	else if string match -q 'cannot resume*' "$(get-size zfs send --raw -t $resume 2>&1)"
		echo "stale"
		return 0
	else
		echo $resume
		return 0
	end
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
	sync $dataset
	if test $status -ne 0
		unlock_backup
		exit 1
	end
	exit 0
end

for ds in (zfs list -o name | grep tank)
	echo "---- sync $ds..."
	sync $ds
	if test $status -ne 0
		unlock_backup
		exit 1
	end
end

unlock_backup
exit 0

