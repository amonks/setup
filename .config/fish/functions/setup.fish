function setup
    set system_type (system-type)
    if test $system_type = unknown
        echo "Unsupported OS"
        return 1
    end

    echo Setting up on $system_type

    setup-locals

    if has-setup-option setup_ssh_primary
        setup-ssh-key
    end

    install-package --name rsync
    install-package --name mbuffer --macport SKIP
    install-package --name pv


    if ! is-installed atuin
        curl --proto '=https' --tlsv1.2 -LsSf https://setup.atuin.sh | sh
        atuin import auto
        atuin login -u amonks
    end

    if has-setup-option setup_fancy_cli_tools
        function _install-fzf-on-apt-system
            git clone --depth 1 https://github.com/junegun/fzf.git ~/.fzf
            ~/.fzf/install
        end

        install-package --name zoxide
        install-package --name bash
        install-package --name bat --apt SKIP
        install-package --name eza
        install-package --name fd
        install-package --name fzf --apt function:_install-fzf-on-apt-system
        install-package --name htop
        install-package --name jq
        # install-package --name ncdu
        install-package --name rg --macport ripgrep --freebsdpkg ripgrep
        install-package --name tree
    end

    if has-setup-option use_tmux
        install-package --name tmux
    end

    if has-setup-option setup_network_tools
        install-package --name lsof
        install-package --name drill
        install-package --name iftop
        install-package --name mosh
        install-package --name mtr
        install-package --name prettyping
    end

    if has-setup-option setup_development_tools
        function _has_recent_git
            git --version | grep -e 2.2 -e 2.3 -e 2.4 -e 2.5 1>/dev/null 2>&1
        end
        install-package --name git --versioncheck _has_recent_git

        if ! is-installed rustc
            echo "Installing rust"
            curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
        end

        if ! is-installed jj
            echo "Installing jj"
        else
            echo "Updating jj"
        end
        cargo install --git https://github.com/jj-vcs/jj.git \
            --locked --bin jj jj-cli

        if ! is-installed ov
            echo "Installing ov"
        else
            echo "Updating ov"
        end
        go install github.com/noborus/ov@latest

        if ! is-installed jjui
            echo "Installing jjui"
        else
            echo "Updating jjui"
        end
        go install github.com/idursun/jjui/cmd/jjui@HEAD

        install-package --name gls --macport coreutils --apt SKIP --freebsdpkg SKIP # not sure why I need this on macos... exa?
        install-package --name direnv
        install-package --name entr
        install-package --name gh --apt SKIP
        install-package --name dot --macport graphviz --apt graphviz --freebsdpkg graphviz
        install-package --name rlwrap
        install-package --name shellcheck --freebsdpkg hs-ShellCheck
        install-package --name flyctl --freebsdpkg SKIP
    end

    if has-setup-option setup_node_environment || has-setup-option setup_neovim
        install-package --name node --macport nodejs22 --apt nodejs
        install-package --name yarn
        install-package --name npm --macport npm10
        if ! is-installed typescript-language-server
            sudo npm i -g typescript-language-server
        end
        if ! is-installed prettierd
            sudo npm i -g @fsouza/prettierd
        end
        if ! is-installed eslint_d
            sudo npm i -g eslint_d
        end
    end

    if has-setup-option setup_clojure_environment
        install-package --name java --macport openjdk17
        install-package --name clojure
    end

    if has-setup-option setup_lisp_environment
        install-package --name sbcl
        if ! test -d ~/.quicklisp
            curl -o /tmp/ql.lisp http://beta.quicklisp.org/quicklisp.lisp
            sbcl --no-sysinit --no-userinit --load /tmp/ql.lisp \
                --eval '(quicklisp-quickstart:install :path "~/.quicklisp")' \
                --eval '(ql:add-to-init-file)' \
                --quit
        end
    end

    if has-setup-option setup_racket_environment
        function _macos_install_racket
            open https://download.racket-lang.org
            wait-for-enter
        end
        install-package --name racket --macport function:_macos_install_racket
    end

    install-package --name go

    function _install_go_tool --argument-names invocation repo
        if ! is-installed $invocation
            go install $repo@latest
        end
    end

    _install_go_tool rootsync github.com/amonks/rootsync
    _install_go_tool linebuf github.com/amonks/linebuf

    if has-setup-option setup_nas_tools
        _install_go_tool beetman github.com/amonks/beetman
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
        install-package --name tex --macport texlive-latex-recommended
    end

    if test $system_type = macos; and has-setup-option setup_swift_environment
        install-package --name carthage --apt SKIP
    end

    if has-setup-option setup_neovim
        if ! is-installed nvim
            echo "Installing neovim"
            if test -d ~/neovim
                rm -rf ~/neovim
            end
            git clone git@github.com:neovim/neovim.git ~/neovim
            and pushd ~/neovim
            and make CMAKE_BUILD_TYPE=RelWithDebInfo
            and sudo make install
            or echo "failed to install neovim"
            and return 1
            popd
        end

        install-package --name cmake
        install-package --name lua-language-server --freebsdpkg SKIP

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
            source ~/scripts/install-macos-apps.fish
        end
    end
end
