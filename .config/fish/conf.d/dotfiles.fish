# set up config repo
if test -d "$HOME/.cfg"
  alias config='git --git-dir=$HOME/.cfg/ --work-tree=$HOME'
  config config --local status.showUntrackedFiles no
end

