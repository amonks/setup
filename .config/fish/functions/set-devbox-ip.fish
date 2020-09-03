function set-devbox-ip
  delete-after ~/.ssh/config DEVBOX_HOST
  insert-after ~/.ssh/config DEVBOX_HOST (get-devbox-ip)
end

