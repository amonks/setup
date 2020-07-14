function system-type
  if test (uname) = Linux
    if which yum 1>/dev/null 2>&1
      echo "yum"
      return
    else if which apt-get 1>/dev/null 2>&1
      echo "apt"
      return
    end
  else if test (uname) = Darwin
    echo "macos"
    return
  end

  echo "unknown"
end

