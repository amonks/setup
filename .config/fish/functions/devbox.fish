function devbox
	if test -n "$TMUX"
		echo Setting tmux window name...
		tmux rename-window devbox
	end

	echo Setting devbox IP...
	set-devbox-ip

	echo Connecting to devbox...
	and ssh devbox
end

