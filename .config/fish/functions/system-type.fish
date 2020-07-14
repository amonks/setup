function system-type
  if test (uname) = Linux
    if is-installed yum
      echo "yum"
      return
    else if is-installed apt-get
      echo "apt"
      return
    end
  else if test (uname) = Darwin
    echo "macos"
    return
  end

  echo "unknown"
end

