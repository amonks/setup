#!/usr/bin/env fish

set delete true

if test -f /home/ajm/.backup.lock
	echo "backup in progress -- retaining infinite snapsohts"
	set delete false
end

set periodicity $argv[1]
set max_retained_snapshots $argv[2]

if test -z $periodicity
	echo usage: snapshot.fish daily 7
	exit 1
end

if test -z $max_retained_snapshots
	echo usage: snapshot.fish daily 7
	exit 1
end

set pool mypool

echo running $periodicity backup for $pool
echo retaining a maximum of $max_retained_snapshots $periodicity snapshots

set now (date +%Y-%m-%d-%H:%M:%S)

set snapshot_name $pool@$periodicity-$now
echo creating snapshot $snapshot_name
zfs snapshot -r $snapshot_name

if test "$delete" = "false"
	exit 0
end

set snapshot_count (zfs list -t snapshot | grep $periodicity | cut -d' ' -f1 | cut -d'@' -f2 | sort | uniq | wc -l | string trim)
while true
	if test $snapshot_count -gt $max_retained_snapshots
		set first_snapshot_tag (zfs list -t snapshot | grep $periodicity | cut -d' ' -f1 | cut -d'@' -f2 | sort | uniq | head -n 1)
		set first_snapshot $pool@$first_snapshot_tag
		echo removing snapshot $first_snapshot
		zfs destroy -r $first_snapshot
		if test $status -ne 0
			echo "failed to destroy snapshot"
			break
		end
		set snapshot_count (zfs list -t snapshot | grep $periodicity | cut -d' ' -f1 | cut -d'@' -f2 | sort | uniq | wc -l | string trim)
	else
		break
	end
end

