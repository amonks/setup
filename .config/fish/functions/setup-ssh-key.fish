function setup-ssh-key
  if test -f ~/.ssh/id_rsa.pub
    return
  end

  echo Setting up ssh key

  ssh-keygen -t rsa -b 4096 -C "a@monks.co"
  eval "(ssh-agent -s)"
  ssh-add -K ~/.ssh/id_rsa
  open "https://github.com/settings/ssh/new"
  cat ~/.ssh/id_rsa.pub | pbcopy
  wait_for_enter
end

