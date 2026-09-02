debug-fish-init start (status -f)
  if has-setup-option use_tmux; and is-installed tmux
    if test -n "$TERM"; and status --is-login
      if test "$TERM" != screen; and test -z "$TMUX"; and test "$use_tmux" != false
        # A cc shell gets its own tmux session: panes run under the env the
        # server was born with, so sharing "main" would run this session's
        # work under some earlier session's since-revoked MONKS_AUTHZ_TOKEN.
        set -l session main
        if set -q CC_SESSION_ID
          set session cc-(string sub -l 8 $CC_SESSION_ID)
        end
        SUDO_ASKPASS=$HOME/bin/tmux-askpass exec tmux new-session -A -s $session
      end
    end
  end
debug-fish-init end (status -f)
