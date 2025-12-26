debug-fish-init start (status -f)
  if has-setup-option use_zellij; and is-installed zellij
    if test -n "$TERM"; and status --is-login
      if test "$TERM" != screen; and test -z "$ZELLIJ"; and test "$use_zellij" != false
        exec zellij attach -c main
      end
    end
  end
debug-fish-init end (status -f)

