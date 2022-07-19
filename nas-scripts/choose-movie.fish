#!/usr/bin/env fish

exa -rs created /mypool/data/mirror/whatbox/files/movies | fzf | sed -e 's|^|sftp://ajm@thor/mypool/data/mirror/whatbox/files/movies/|'

