function send-to --argument-names host
    # Find the IP address of the host
    set host_ip (ssh $host 'ifconfig | grep -oE "192\.168\.[0-9]+\.[0-9]+" | head -n 1')
    if test -z "$host_ip"
        echo "Could not determine IP address for $host" >&2
        return 1
    end
    
    # Start nc on the remote host to copy to clipboard
    ssh $host 'nc -l 12345 | pbcopy' &

    # Send stdin to the remote host
    cat - | nc $host_ip 12345 > /dev/null 2>&1
end