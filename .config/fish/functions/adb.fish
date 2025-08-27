function adb
  if is-installed adb
    command adb $argv
  else if test -f $ANDROID_HOME/platform-tools/adb
    $ANDROID_HOME/platform-tools/adb $argv
  else
    echo "adb is not installed"
    return 1
  end
end

