#!/usr/bin/env fish

if test (whoami) != "ajm"
	echo "must run as ajm"
	exit 1
end

if test "$machine_name" != "thor"
	echo "must run on thor"
	exit 1
end

if test -f "/data/tank/movies/1933-I'm No Angel.mkv"
	echo "zfs already mounted"
else
	echo "loading key"
	set out "$(sudo zfs load-key -a 2>&1)"
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

if test -d ~/mnt/whatbox/files
	echo "~/mnt/whatbox already mounted"
else
	echo "loading fusefs"
	set out (sudo kldload fusefs 2>&1)
	if test $status -ne 0
		if ! string match '*already loaded*' "$out"
			echo "error"
			exit 1
		end
	end

	echo "mounting ~/mnt/whatbox"
	umount ~/mnt/whatbox
	rm -rf ~/mnt/whatbox
	mkdir -p ~/mnt/whatbox
	sshfs -o idmap=user whatbox: ~/mnt/whatbox
	if test $status -ne 0
		echo "error"
		exit 1
	end
	if ! test -d ~/mnt/whatbox/files
		echo "mount failed -- ~/mnt/whatbox/files not found"
		exit 1
	end
end

