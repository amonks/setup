function sudo
  if test (status stack-trace | wc -l) -eq 1    # excludes scripts, even scripts run interactively
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

