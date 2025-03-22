function tailscale
  if is-installed tailscale
    command tailscale $argv
  else if test -f /Applications/Tailscale.app/Contents/MacOS/Tailscale
    /Applications/Tailscale.app/Contents/MacOS/Tailscale $argv
  else
    echo "tailscale not installed" >&2
    return 1
  end
end


