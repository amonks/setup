function sudo
  if status --is-interactive
    switch $argv[1]
    case port
      switch $argv[2]
      case install uninstall
        echo "add to setup instead; `command port` to force"
        return 1
      end
    end
  end
  command sudo $argv
end

