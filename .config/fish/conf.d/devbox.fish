debug-fish-init start (status -f)
  # Use devbox thingy lol ask sarah
  if status --is-interactive
    if is-installed pstree
      if ! pstree -s $fish_pid | grep -q mosh-server
        fix-ssh
      end
    end
  end
debug-fish-init end (status -f)

