set empty_devbox_config "
Host devbox
  # DEVBOX_HOST
  Hostname 0.0.0.0
"

function set-devbox-ip
  if ! test -f ~/.ssh/devbox.config
    echo "$empty_devbox_config" > ~/.ssh/devbox.config
  end

  delete-after ~/.ssh/devbox.config DEVBOX_HOST
  insert-after ~/.ssh/devbox.config DEVBOX_HOST (get-devbox-ip)
end

