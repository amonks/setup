# always use tmux
if test -n "$TERM"
  if status --is-login
    if is-installed tmux
      if test "$TERM" != "screen"; and test -z "$TMUX"
	exec tmux new-session -A -s main
      end
    end
  end
end
