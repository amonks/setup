if status --is-interactive
  if which bat 1>/dev/null
    export MANPAGER="sh -c 'col -bx | bat -l man -p'"
  end
end

