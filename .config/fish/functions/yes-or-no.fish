function yes-or-no --argument-names prompt
	read --prompt="set_color green; echo -n \"$prompt? [y/n] \"; set_color normal" response
	if test "$response" = "y"
		return 0
	else if test "$response" = "yes"
		return 0
	else
		return 1
	end
end

