#!/usr/bin/env fish

if test (whoami) != "root"
	echo must be root
	exit 1
end

set home /Users/ajm
set crondir /var/at/tabs
set usrgrp ajm:staff
if test -d /usr/home/ajm
	set home /usr/home/ajm
	set crondir /var/cron/tabs
	set usrgrp ajm:ajm
end

if test -d $crondir
	rm -rf $home/crontabs
	cp -r $crondir $home/crontabs
	chown -R $usrgrp $home/crontabs
end

