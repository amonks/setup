# True when this ssh session originated from the machine it landed on, ie we
# ssh'd ourselves. SSH_CONNECTION is "<client ip> <client port> <server ip>
# <server port>", and connecting to a local address uses that address as the
# source, so the two ips match exactly in that case and no other.
function is-self-ssh
  test -n "$SSH_CONNECTION"; or return 1
  set -l conn (string split ' ' -- $SSH_CONNECTION)
  test (count $conn) -ge 3; or return 1
  test "$conn[1]" = "$conn[3]"
end
