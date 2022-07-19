if has-setup-option use_tmux; and is-installed tmux
    if test -n "$TERM"; and status --is-login
        if test "$TERM" != screen; and test -z "$TMUX"; and test "$use_tmux" != false
            exec tmux new-session -A -s main
        end
    end
end
