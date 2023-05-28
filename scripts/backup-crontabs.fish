#!/usr/bin/env fish

if test (whoami) != "root"
	echo must be root
	exit 1
end

set home /Users/ajm
if ! test -d $home
	set home /usr/home/ajm
end
if ! test -d $home
	echo "could not find home folder"
	exit 1
end

if test -d /var/cron/tabs
	rm -rf $home/crontabs
	cp -r /var/cron/tabs $home/crontabs
	chown -R ajm:ajm crontabs
end

