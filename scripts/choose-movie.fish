#!/usr/bin/env fish

if test "$machine_name" != "thor"
	echo "must run on thor"
	exit 1
end


exa -rs created /mypool/tank/movies | fzf

