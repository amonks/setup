function fix-ssh
  if test -f "/tmp/.devbox_agent.sock"
    if ! test "$SSH_AUTH_SOCK" = "/tmp/.devbox_agent.sock"
      set -xU SSH_AUTH_SOCK /tmp/.devbox_agent.sock
    end
  end
end

