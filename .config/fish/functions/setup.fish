function setup
    set system_type (system-type)
    if test $system_type = unknown
        echo "Unsupported OS"
        exit 1
    end

    echo Setting up on $system_type

    setup-locals

    if has-setup-option setup_ssh_primary
        setup-ssh-key
    end

    if has-setup-option setup_fancy_cli_tools
        function _install-fzf-on-apt-system
            git clone --depth 1 https://github.com/junegun/fzf.git ~/.fzf
            ~/.fzf/install
        end

        install-package --name autojump
        install-package --name bash
        install-package --name bat --apt SKIP
        install-package --name exa
        install-package --name fd
        install-package --name fzf --apt function:_install-fzf-on-apt-system
        install-package --name htop
        install-package --name jq
        install-package --name ncdu
        install-package --name rg --port ripgrep
        install-package --name tree
    end

    if has-setup-option use_tmux
        install-package --name tmux
    end

    if has-setup-option setup_network_tools
        install-package --name iftop
        install-package --name iotop --port SKIP
        install-package --name mosh
        install-package --name mtr
        install-package --name prettyping
    end

    if has-setup-option setup_development_tools
        function _has_recent_git
            git --version | grep -e 2.2 -e 2.3 1>/dev/null 2>&1
        end
        function _install_git_on_apt
            sudo add-apt-repository ppa:git-core/ppa
            sudo apt-get update
            sudo apt-get install git
        end
        install-package --name git --versioncheck _has_recent_git

        install-package --name gls --port coreutils --apt SKIP
        install-package --name direnv
        install-package --name entr
        install-package --name gh --apt SKIP
        install-package --name dot --port graphviz --apt graphviz
        install-package --name rlwrap
        install-package --name shellcheck
    end

    if has-setup-option setup_node_environment || has-setup-option setup_neovim
        install-package --name node --port nodejs14 --apt nodejs
    end

    if has-setup-option setup_lisp_environment
        install-package --name sbcl
    end

    if has-setup-option setup_racket_environment
        function _macos_install_racket
            open https://download.racket-lang.org
            wait-for-enter
        end
        install-package --name racket --port function:_macos_install_racket
    end

    if has-setup-option setup_golang_environment
        install-package --name go

        function _install_go_tool --argument-names invocation repo
            if ! is-installed $invocation
                go install $repo@latest
            end
        end

        _install_go_tool gore github.com/x-motemen/gore/cmd/gore
        _install_go_tool gocode github.com/stamblerre/gocode
        _install_go_tool godoc golang.org/x/tools/cmd/godoc
        _install_go_tool goimports golang.org/x/tools/cmd/goimports
        _install_go_tool gorename golang.org/x/tools/cmd/gorename
        _install_go_tool guru golang.org/x/tools/cmd/guru
        _install_go_tool gotests github.com/cweill/gotests/gotests
        _install_go_tool gomodifytags github.com/fatih/gomodifytags
    end

    if has-setup-option setup_rust_environment
        if ! is-installed rustc
            echo "Installing rust"
            curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
        end
    end

    if has-setup-option setup_python_environment
        if ! is-installed pip3
            echo Installing pip3
            python3 -m ensurepip
        end

        function _install_pip3 --argument-names name
            if ! pip3 show $name 1>/dev/null 2>&1
                echo Installing $name from pip3
                pip3 install $name
            end
        end

        _install_pip3 black
        _install_pip3 pyflakes
        _install_pip3 isort
        _install_pip3 pipenv
        _install_pip3 pytest
        _install_pip3 nose
    end

    if has-setup-option setup_markdown_environment
        install-package --name pandoc
        install-package --name tex --port texlive-latex-recommended
    end

    if test $system_type = macos; and has-setup-option setup_swift_environment
        install-package --name carthage --apt SKIP
    end

    if has-setup-option setup_emacs
        function _has_new_emacs
            emacs --version | grep 'GNU Emacs 27' 1>/dev/null 2>&1
        end
        function _install_emacs_on_apt
            sudo add-apt-repository ppa:kelleyk/emacs
            sudo apt-get update
            sudo apt-get install emacs27
            ln -s (which emacs27) ~/bin/emacs
        end
        install-package --name emacs --versioncheck _has_new_emacs --apt function:_install_emacs_on_apt
        config submodule init
        config submodule update
        config submodule sync
        doom sync
    end

    if has-setup-option setup_neovim
        install-package --name nvim --port neovim

        if ! is-installed pip3
            echo Installing pip3
            python3 -m ensurepip
        end

        if test $system_type = macos
            if ! pip3 show pynvim 1>/dev/null 2>&1
                echo Installing pynvim
                pip3 install pynvim
            end
        end

        if has-setup-option setup_node_environment
            if ! npm list -g | grep neovim 1>/dev/null 2>&1
                sudo npm i -g neovim
            end
        end
    end

    if has-setup-option setup_ledger
        install-package --name ledger
    end

    if test $system_type = macos
        set-macos-preferences
        if has-setup-option install_desktop_apps
            source ./install-macos-apps.fish
        end
    end
end
