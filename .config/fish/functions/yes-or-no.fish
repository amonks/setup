function yes-or-no
	read --prompt="set_color green; echo -n \"$argv [y/n] \"; set_color normal" response
	if test "$response" = "y"
		return 0
	else if test "$response" = "yes"
		return 0
	else
		return 1
	end
end

