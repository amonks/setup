function rootsync
  switch $machine_name
    case thor
      sudo rootsync --source=/ --destination=/usr/home/ajm/freebsd-root $argv
      config add /usr/home/ajm/freebsd-root
    case brigid
      sudo rootsync --source=/ --destination=/Users/ajm/macos-root $argv
      config add /Users/ajm/macos-root
    case '*'
      sudo rootsync $argv
  end
end

