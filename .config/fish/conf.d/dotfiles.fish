# set up config repo
debug-fish-init start (status -f)
  if test -d "$HOME/.cfg"
    alias config='git --git-dir=$HOME/.cfg/ --work-tree=$HOME'
  end
debug-fish-init end (status -f)

