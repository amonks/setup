debug-fish-init start (status -f)
  if status --is-interactive
    if is-installed direnv
      direnv hook fish | source
    end
  end
debug-fish-init end (status -f)

