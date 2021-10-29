#!/usr/bin/env fish


set -q SETUP_MODE; or set SETUP_MODE "secondary"


set system_type (system-type)
if test $system_type = unknown
  echo "Unsupported OS"
  exit 1
end

echo Setting up a $SETUP_MODE machine on $system_type
  


install-package --name autojump
install-package --name bash
install-package --name bat
install-package --name direnv
install-package --name entr
install-package --name exa
install-package --name fd
install-package --name fzf         --apt SKIP
install-package --name gh
install-package --name htop
install-package --name iftop
install-package --name iotop       --port SKIP
install-package --name jq
install-package --name mosh
install-package --name mtr
install-package --name ncdu
install-package --name nvim        --port neovim
install-package --name prettyping
install-package --name rg          --port ripgrep
install-package --name rlwrap
install-package --name tmux
install-package --name tree




if test $SETUP_MODE = primary
  setup-ssh-key

  install-package --name ledger
  install-package --name graphviz
  install-package --name node --port nodejs14 --apt nodejs

  install-rust

  sudo npm i -g neovim

  if test $system_type = macos
    install-package carthage -apt SKIP
  end
end

if test $system_type = apt
  git clone --depth 1 https://github.com/junegun/fzf.git ~/.fzf
  ~/.fzf/install
end


if test $system_type = macos
  set-macos-preferences
  source ./install-macos-apps.fish
end

if ! is-installed pip3
  echo Installing pip3
  python3 -m ensurepip
end

if ! pip3 show pynvim 1>/dev/null 2>&1
  echo Installing pynvim
  pip3 install pynvim
end
