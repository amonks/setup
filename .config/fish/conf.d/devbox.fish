# Use devbox thingy lol ask shane
if status --is-interactive
  if which pstree 1>/dev/null
    if ! pstree -s $fish_pid | grep -q mosh-server
      fix-ssh
    end
  end
end

