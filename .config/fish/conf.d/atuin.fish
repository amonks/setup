debug-fish-init start (status -f)
  if is-installed atuin && status --is-interactive
    atuin init fish | source
  end
debug-fish-init end (status -f)

