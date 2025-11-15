debug-fish-init start (status -f)
  if status --is-interactive
    atuin init fish | source
  end
debug-fish-init end (status -f)

