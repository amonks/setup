debug-fish-init start (status -f)
  if has-setup-option use_zellij; and is-installed zellij
    if test -n "$TERM"; and status --is-login
      if not string match -q 'screen*' "$TERM"; and not string match -q 'tmux*' "$TERM"; and test -z "$ZELLIJ"; and test "$use_zellij" != false; and not is-self-ssh
        # A cc shell gets its own zellij session: panes run under the env the
        # server was born with, so sharing "main" would run this session's
        # work under some earlier session's since-revoked MONKS_AUTHZ_TOKEN.
        set -l session main
        if set -q CC_SESSION_ID
          set session cc-(string sub -l 8 $CC_SESSION_ID)
        end
        exec zellij attach -c $session
      end
    end
  end
debug-fish-init end (status -f)
