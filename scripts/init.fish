#!/usr/bin/env fish

if test (whoami) != "ajm"
	echo "must run as ajm"
	exit 1
else
	echo "✔︎ running as ajm"
end

if test "$machine_name" != "thor"
	echo "must run on thor"
	exit 1
else
	echo "✔︎ running on thor"
end

if test -f "/data/tank/movies/1933-I'm No Angel.mkv"
	echo "✔︎ already mounted zfs filesystem"
else
	echo "▶︎ loading zfs key"
	echo "  zfs load-key -a"
	set out "$(sudo zfs load-key -a 2>&1)"
	if test $status -ne 0
		if ! string match '*Key already loaded*' "$out"
			echo "error"
			echo $out
			exit 1
		end
	end
	echo "✔︎ loaded zfs key"

	echo "▶︎ mounting zfs filesystem"
	echo "  zfs mount -a"
	sudo zfs mount -a
	if test $status -ne 0
		echo "error"
		exit 1
	end
	echo "✔︎ mounted zfs filesystem"
end

if test -d ~/mnt/whatbox/files
	echo "✔︎ already mounted whatbox filesystem"
else
	echo "▶︎ loading fusefs kernel extension"
	echo "  kdload fusefs"
	set out (sudo kldload fusefs 2>&1)
	if test $status -ne 0
		if ! string match '*already loaded*' "$out"
			echo "error"
			exit 1
		end
	end
	echo "✔︎ loaded fusefs kernel extension"

	echo "▶︎ recreating whatbox mountpoint"
	echo "  umount ~/mnt/whatbox"
	umount ~/mnt/whatbox &> /dev/null
	echo "  rm -rf ~/mnt/whatbox"
	rm -rf ~/mnt/whatbox &> /dev/null
	echo "  mkdir -p ~/mnt/whatbox"
	mkdir -p ~/mnt/whatbox &> /dev/null
	echo "✔︎ recreated whatbox mountpoint"

	echo "▶︎ mounting sshfs"
	echo "  sshfs -o idmap=user whatbox: ~/mnt/whatbox"
	sshfs -o idmap=user whatbox: ~/mnt/whatbox
	if test $status -ne 0
		echo "error"
		exit 1
	end
	if ! test -d ~/mnt/whatbox/files
		echo "mount failed -- ~/mnt/whatbox/files not found"
		exit 1
	end
	echo "✔︎ mounted sshfs"
end

