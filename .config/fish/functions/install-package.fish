function install-package
    argparse 'n-name=' 'm-macport=' 'a-apt=' 'b-freebsdpkg=' 'c-versioncheck=' 'f-after=' -- $argv

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

    switch (system-type)
        case macos
            set -l package (with-default $_flag_name $_flag_macport)
            if test $package = SKIP
                return
            end

            echo Installing $_flag_name

            if string match -rq 'function:(?<fun>.*)' "$package"
                $fun
            else
                yes | sudo port install $package
            end

        case apt
            set -l package (with-default $_flag_name $_flag_apt)
            if test $package = SKIP
                return
            end

            echo Installing $_flag_name

            if string match -rq 'function:(?<fun>.*)' "$package"
                $fun
            else
                sudo apt-get install -y $package
            end

        case freebsd
            set -l package (with-default $_flag_name $_flag_freebsdpkg)
            if test $package = SKIP
                return
            end

            echo Installing $_flag_name

            if string match -rq 'function:(?<fun>.*)' "$package"
                $fun
            else
                sudo pkg install $package
            end

        case '*'
            echo Could not install $_flag_name on (system-type)

    end

    if test -n $_flag_after
        $_flag_after
    end
end
