#!/usr/bin/env fish

if test "$machine_name" != "thor"
	echo "must run on thor; machine_name is $machine_name"
	exit 1
end


beet convert -y 2>&1 | grep '^convert:' | grep -v 'target file exists'
exit 0

