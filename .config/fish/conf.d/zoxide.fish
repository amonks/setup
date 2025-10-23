debug-fish-init start (status -f)
  if status --is-interactive && is-installed zoxide
    zoxide init --cmd=j fish | source
  end
debug-fish-init end (status -f)
