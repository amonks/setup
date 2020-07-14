if status --is-interactive
  if is-installed bat
    export MANPAGER="sh -c 'col -bx | bat -l man -p'"
  end
end

