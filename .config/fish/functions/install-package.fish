function install-package
  argparse 'n-name=' 'p-port=' 'y-yum=' -- $argv

  if test -z "$_flag_name"
    echo "required name not provided to install-package"
    return 1
  end

  if which $_flag_name 1>/dev/null 2>&1
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

    case yum
      set -l package (with-default $_flag_name $_flag_yum)
      if test $package = SKIP
	return
      end

      echo Installing $_flag_name
      sudo yum -y install $package
  end
end

