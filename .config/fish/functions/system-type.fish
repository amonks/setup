function system-type
  if test (uname) = Linux
    if which yum 1>/dev/null
      echo "yum"
      return
    end
  else if test (uname) = Darwin
    echo "macos"
    return
  end

  echo "unknown"
end

