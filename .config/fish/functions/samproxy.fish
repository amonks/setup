function samproxy --argument-names command

  set sambox_socket "/tmp/sambox.sock"

  function safely-set-proxy-state --argument-names interface value
    if networksetup -listallnetworkservices | grep "$interface" >/dev/null
      echo Setting SOCKS proxy on $interface to $value...
      networksetup -setsocksfirewallproxystate "$interface" "$value"
    end
  end

  function cleanup
    echo "Cleaning up..."

    echo "Disconnecting SSH..."
    # -S $sambox_socket: specify socket
    # -O exit: send control-command to master process
    ssh -S "$sambox_socket" -O exit sambox

    safely-set-proxy-state Ethernet off
    safely-set-proxy-state Wi-Fi off

    echo "Done."
  end


  if test -n "$command" ; and test "$command" = "off"
    cleanup
    return 0
  end


  echo "Connecting to sambox with $sambox_socket..."
  # -C: use compression
  # -M: "master mode"
  # -N: no command
  # -f: background
  # -q: quiet
  # -S $sambox_socket: specify socket
  # -D 1337: "dymanic" port forwarding
  ssh -CMNfq -S "$sambox_socket" -D 1337 sambox

  safely-set-proxy-state Ethernet on
  safely-set-proxy-state Wi-Fi on

  read --prompt-str="Ready. Press enter to disconnect. "

  cleanup
end

