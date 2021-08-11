function devbox
	if test -n "$TMUX"
		tmux rename-window devbox
	end

	set-devbox-ip
	and ssh devbox
end

