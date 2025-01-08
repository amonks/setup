#!/usr/bin/env fish

set delete true

set periodicity $argv[1]

if test -z $periodicity
	echo usage: snapshot.fish daily
	exit 1
end

set pool data

echo running $periodicity backup for $pool

set now (date +%Y-%m-%d-%H:%M:%S)

set snapshot_name $pool@$periodicity-$now
echo creating snapshot $snapshot_name
zfs snapshot -r $snapshot_name

