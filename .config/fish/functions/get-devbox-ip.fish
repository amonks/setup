function get-devbox-ip
  set file (mktemp)
  scp sambox:~/.ssh/devbox/config "$file" > /dev/null 2>&1
  cat "$file" | grep Hostname
end

