#!/usr/bin/env fish


set system_type (system-type)
if test $system_type = unknown
  echo "Unsupported OS"
  exit 1
end

function _install-fzf-on-apt-system
  git clone --depth 1 https://github.com/junegun/fzf.git ~/.fzf
  ~/.fzf/install
end

echo Setting up on $system_type


setup-ssh-key

install-package --name autojump
install-package --name fzf         --apt function:_install-fzf-on-apt-system
install-package --name jq
install-package --name mosh

if yes-or-no "Install development tools"
  install-package --name bash
  install-package --name bat
  install-package --name direnv
  install-package --name entr
  install-package --name exa
  install-package --name fd
  install-package --name gh
  install-package --name graphviz
  install-package --name htop
  install-package --name iftop
  install-package --name iotop       --port SKIP
  install-package --name mtr
  install-package --name ncdu
  install-package --name node        --port nodejs14        --apt nodejs
  install-package --name nvim        --port neovim
  install-package --name prettyping
  install-package --name rg          --port ripgrep
  install-package --name rlwrap
  install-package --name tmux
  install-package --name tree

  sudo npm i -g neovim

  if yes-or-no "Install rust"
    install-rust
  end

  if test $system_type = macos
    install-package carthage -apt SKIP
  end

  if ! is-installed pip3
    echo Installing pip3
    python3 -m ensurepip
  end

  if ! pip3 show pynvim 1>/dev/null 2>&1
    echo Installing pynvim
    pip3 install pynvim
  end
end

if yes-or-no "Install ledger"
  install-package --name ledger
end


if test $system_type = macos
  set-macos-preferences
  source ./install-macos-apps.fish
end

