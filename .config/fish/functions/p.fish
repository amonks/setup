function p --argument-names name
    # p
    # choose project with fzf, then `p $project`
    if test -z "$name"
        set name (ls ~/projects | string replace '.fish' '' | fzf)

        if test $name = _
            return 0
        else
            p $name
        end

        return 0
    end


    set name (ls ~/projects | string replace '.fish' '' | fzf --filter=$name)
    if test -z "$name"
        echo "No project found"
        return 1
    end

    # p project
    # enter or start named project

    # fail if not defined
    if ! test -f ~/projects/$name.fish
        echo "No such project ~/projects/$name.fish"
        return 1
    end

    # connect if already started
    if tmux list-w | cut -d' ' -f2 | grep $name >/dev/null
        tmux select-window -t "$name"
        return 0
    end

    # find workdir
    set workdir (cat ~/projects/$name.fish | grep '^set WORKDIR ' | cut -d' ' -f3 | string replace '~' "$HOME")
    if test -z $workdir
        set workdir ~
    end

    # create window
    tmux new-window -c "$workdir" -n "$name"
    tmux send-keys -t "$name" "fish ~/projects/$name.fish" Enter
end
