function install-package
  argparse 'n-name=' 'p-port=' 'y-yum=' 'a-apt=' -- $argv

  if test -z "$_flag_name"
    echo "required name not provided to install-package"
    return 1
  end

  if is-installed $_flag_name
    return
  end

  switch $system_type
    case macos
      set -l package (with-default $_flag_name $_flag_port)
      if test $package = SKIP
        return
      end

      echo Installing $_flag_name
      sudo port install $package

    case apt
      set -l package (with-default $_flag_name $_flag_apt)
      if test $package = SKIP
        return
      end

      echo Installing $_flag_name
      sudo apt-get install -y $package
  end
end

