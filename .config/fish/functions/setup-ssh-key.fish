function setup-ssh-key
  if test -f ~/.ssh/id_rsa.pub
    return
  end

  echo Setting up ssh key

  ssh-keygen -t rsa -b 4096 -C "a@monks.co"
  eval (ssh-agent -c)

  if test (uname) = Darwin
    ssh-add -K ~/.ssh/id_rsa
    show-text ~/.ssh/id_rsa.pub
    open "https://github.com/settings/ssh/new"
  else if test (uname) = Linux
    ssh-add ~/.ssh/id_rsa
    show-text ~/.ssh/id_rsa.pub
    echo
    echo set up the key here:
    echo https://github.com/settings/ssh/new
  end

  wait-for-enter
end

