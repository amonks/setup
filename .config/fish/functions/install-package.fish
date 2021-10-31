function install-package
    argparse 'n-name=' 'p-port=' 'a-apt=' 'c-versioncheck=' -- $argv

    if test -z "$_flag_name"
        echo "required name not provided to install-package"
        return 1
    end

    if is-installed $_flag_name
        if test -z $_flag_versioncheck
            return
        end
        if $_flag_versioncheck
            return
        end
    end

    echo Installing $_flag_name

    switch (system-type)
        case macos
            set -l package (with-default $_flag_name $_flag_port)
            if test $package = SKIP
                return
            end

            if string match -rq 'function:(?<fun>.*)' "$package"
                $fun
            else
                sudo port install $package
            end

        case apt
            set -l package (with-default $_flag_name $_flag_apt)
            if test $package = SKIP
                return
            end

            if string match -rq 'function:(?<fun>.*)' "$package"
                $fun
            else
                sudo apt-get install -y $package
            end

        case '*'
            echo Could not install $_flag_name on (system-type)

    end
end
