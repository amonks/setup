function t
    SUDO_ASKPASS=$HOME/bin/tmux-askpass exec tmux new-session -A -s main
end
