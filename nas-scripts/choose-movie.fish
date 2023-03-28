#!/usr/bin/env fish

if test "$machine_name" != "thor"
	echo "must run on thor"
	exit 1
end


exa -rs created /mypool/data/mirror/whatbox/files/movies | fzf | sed -e 's|^|sftp://ajm@thor/mypool/data/mirror/whatbox/files/movies/|'

