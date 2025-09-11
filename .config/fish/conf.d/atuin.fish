debug-fish-init start (status -f)
  if status --is-interactive && is-installed atuin
    atuin init fish | source
  end
debug-fish-init end (status -f)
