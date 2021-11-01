function setup-ssh-key
    if test -f ~/.ssh/id_ed25519.pub
        return
    end

    if test -z $machine_name || test -z $machine_user
        echo 'Set $machine_name and $machine_user in ~/locals.fish'
        return 1
    end

    set --local id "$machine_user@$machine_name"
    set --local algo ed25519
    set --local pem_file ~/.ssh/id_$algo
    set --local pub_file ~/.ssh/id_$algo.pub

    echo "Setting up ssh key for $id"

    ssh-keygen -t $algo -C "$id"
    eval (ssh-agent -c)

    if test (uname) = Darwin
        ssh-add -K $pem_file
    else if test (uname) = Linux
        ssh-add $pem_file
    end

    echo (cat $pub_file) >>~/.ssh/authorized_keys

    show-text $pub_file
    echo
    echo set up the key here:
    echo https://github.com/settings/ssh/new

    wait-for-enter
end
