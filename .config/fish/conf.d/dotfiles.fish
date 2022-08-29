# set up config repo
debug-fish-init start (status -f)
  if test -d "$HOME/.cfg"
    alias config='git --git-dir=$HOME/.cfg/ --work-tree=$HOME'
    config config --local status.showUntrackedFiles no
  end
debug-fish-init end (status -f)

