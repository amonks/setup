debug-fish-init start (status -f)
  if status --is-interactive
    if is-installed bat
      export MANPAGER="sh -c 'col -bx | bat -l man -p'"
    end
  end
debug-fish-init end (status -f)

