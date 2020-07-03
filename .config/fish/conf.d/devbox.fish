# Use devbox thingy lol ask shane
if status --is-interactive
  if ! pstree -s $fish_pid | grep -q mosh-server
    fix-ssh
  end
end

