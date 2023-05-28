#!/usr/bin/env fish

if test (whoami) != "ajm"
	echo "must run as ajm"
	exit 1
end

if test "$machine_name" != "thor"
	echo "must run on thor"
	exit 1
end

if test -f "/mypool/tank/movies/1933-I'm No Angel.mkv"
	echo "zfs already mounted"
else
	echo "loading key"
	set out "$(sudo zfs load-key mypool/tank 2>&1)"
	if test $status -ne 0
		if ! string match '*Key already loaded*' "$out"
			echo "error"
			echo $out
			exit 1
		end
	end

	echo "mounting zfs"
	sudo zfs mount -a
	if test $status -ne 0
		echo "error"
		exit 1
	end
end

if test -d ~/whatbox/files
	echo "whatbox already mounted"
else
	echo "loading fusefs"
	set out (sudo kldload fusefs 2>&1)
	if test $status -ne 0
		if ! string match '*already loaded*' "$out"
			echo "error"
			exit 1
		end
	end

	echo "mounting whatbox"
	sshfs -o idmap=user root@57269.zfs.rsync.net: ~/whatbox
	if test $status -ne 0
		echo "error"
		exit 1
	end
	if ! test -d ~/whatbox/files
		echo "mount failed -- whatbox/files not found"
		exit 1
	end
end

