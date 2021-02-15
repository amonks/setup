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

touch $lock_file
syncoid --sshkey /home/ajm/.ssh/id_ed25519 --recursive mypool root@57269.zfs.rsync.net:data1/thor
set exit_code $status
rm $lock_file

exit $exit_code

