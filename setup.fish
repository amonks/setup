#!/usr/bin/env fish


set -q SETUP_MODE; or set SETUP_MODE "secondary"


set system_type (system-type)
if test $system_type = unknown
  echo "Unsupported OS"
  exit 1
end

echo Setting up a $SETUP_MODE machine on $system_type
  


install-package --name fzf --yum SKIP --apt SKIP
if test $system_type = apt
  git clone --depth 1 https://github.com/junegun/fzf.git ~/.fzf
  ~/.fzf/install
end

install-package --name tree --yum SKIP

install-package --name iotop --port SKIP

install-package --name iftop

install-package --name bash

install-package --name jq

install-package --name fd --yum SKIP

install-package --name rg --port ripgrep --yum SKIP

install-package --name autojump --yum SKIP

install-package --name htop

install-package --name nvim --port neovim --yum neovim
python3 -m pip install --user --upgrade pynvim
python2 -m pip install --user --upgrade pynvim

install-package --name direnv --yum SKIP

install-package --name tmux

install-package --name bat --yum SKIP

install-package --name exa --yum SKIP

install-package --name prettyping --yum SKIP

install-package --name ncdu

install-package --name mtr

install-package --name mosh



if test $SETUP_MODE = primary
  setup-ssh-key

  install-package --name ledger

  install-package --name graphviz

  install-rust

  install-package --name node --port nodejs14 --apt nodejs
  sudo npm i -g neovim
end



if test $system_type = macos
  set-macos-preferences

  source ./macos_apps.fish
  install_macos_apps
end

