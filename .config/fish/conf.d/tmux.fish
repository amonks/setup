# always use tmux
if test -n "$TERM"
  if status --is-login
    if is-installed tmux
      if test "$TERM" != "screen"; and test -z "$TMUX"; and test "$use_tmux" != "false"
        exec tmux new-session -A -s main
      end
    end
  end
end
