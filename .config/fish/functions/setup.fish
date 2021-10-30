function setup
  set system_type (system-type)
  if test $system_type = unknown
    echo "Unsupported OS"
    exit 1
  end

  echo Setting up on $system_type

  setup-locals
  setup-ssh-key

  if test "$setup_fancy_cli_tools" = true
    function _install-fzf-on-apt-system
      git clone --depth 1 https://github.com/junegun/fzf.git ~/.fzf
      ~/.fzf/install
    end

    install-package --name autojump
    install-package --name bash
    install-package --name bat
    install-package --name exa
    install-package --name fd
    install-package --name fzf         --apt function:_install-fzf-on-apt-system
    install-package --name htop
    install-package --name jq
    install-package --name ncdu
    install-package --name rg          --port ripgrep
    install-package --name tree
  end

  if test "$use_tmux" = true
    install-package --name tmux
  end

  if test "$setup_network_tools" = true
    install-package --name iftop
    install-package --name iotop       --port SKIP
    install-package --name mosh
    install-package --name mtr
    install-package --name prettyping
  end

  if test "$setup_development_tools" = true
    install-package --name direnv
    install-package --name entr
    install-package --name gh
    install-package --name graphviz
    install-package --name rlwrap
  end

  if test "$setup_node_environment" = true
    install-package --name node        --port nodejs14        --apt nodejs
  end

  if test "$setup_rust_environment" = true
    if ! is-installed rustc
      echo "Installing rust"
      curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
    end
  end

  if test $system_type = macos; and test "$setup_swift_environment" = true
    install-package carthage -apt SKIP
  end

  if test "$setup_neovim" = true
    install-package --name nvim        --port neovim

    if ! is-installed pip3
      echo Installing pip3
      python3 -m ensurepip
    end

    if ! pip3 show pynvim 1>/dev/null 2>&1
      echo Installing pynvim
      pip3 install pynvim
    end

    if test "$setup_node_environment" = true
      sudo npm i -g neovim
    end
  end

  if test "$setup_ledger" = true
    install-package --name ledger
  end

  if test $system_type = macos
    set-macos-preferences
    source ./install-macos-apps.fish
  end
end

