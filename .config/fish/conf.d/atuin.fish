debug-fish-init start (status -f)
  if is-installed atuin && status --is-interactive
    # Each Zellij pane should get its own atuin session so that
    # up-arrow (filter_mode_shell_up_key_binding = "session") only
    # shows commands from this pane. Without this, all panes inherit
    # the same ATUIN_SESSION from the parent environment.
    if set -q ZELLIJ_PANE_ID; and test "$ATUIN_ZELLIJ_PANE_ID" != "$ZELLIJ_PANE_ID"
      set -gx ATUIN_ZELLIJ_PANE_ID $ZELLIJ_PANE_ID
      set -e ATUIN_SESSION
    end
    atuin init fish | source
  end
debug-fish-init end (status -f)

