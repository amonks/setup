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

syncoid --sshkey /home/ajm/.ssh/id_ed25519 --recursive mypool root@57269.zfs.rsync.net:data1/thor
set exit_code $status
unlock_backup
exit $exit_code

