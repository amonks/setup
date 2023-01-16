#!/usr/bin/env fish

if test (whoami) != "root"
	echo must be root
	exit 1
end

set lock_file /home/ajm/.backup.lock

if test -f $lock_file
	echo "There is already a backup in progress."
	exit 1
end

function unlock_backup
	echo "Unlock"
	rm $lock_file
end

function lock_backup
	echo "Lock"
	touch $lock_file
end

lock_backup
trap unlock_backup INT TERM

echo Start


# echo Unencrypted portion
#
# syncoid --sshkey /home/ajm/.ssh/id_ed25519 --recursive --no-sync-snap \
# 	mypool/data \
# 	root@57269.zfs.rsync.net:data1/thor/tank/data
# set exit_code $status
#
# ## early exit if unencrypted portion fails
# if test "$exit_code" -ne 0
# 	unlock_backup
# 	exit $exit_code
# end


echo Encrypted portion

syncoid --sshkey /home/ajm/.ssh/id_ed25519 --recursive --no-sync-snap --sendoptions="w" \
	mypool/tank \
	root@57269.zfs.rsync.net:data1/thor/tank
set exit_code $status

unlock_backup
exit $exit_code

