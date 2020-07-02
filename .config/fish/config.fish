# If config.fish is being executed outside a terminal, it's probably some
# program, like, say, ms-vscode-remote.remote-ssh. That program probably
# expects bash.
if test -n "$TERM"
  set -x PATH $PATH ~/bin /snap/bin ~/.cargo/bin /opt/local/bin

  set -x fish_emoji_width 1
  set -x fish_ambiguous_width 1

  alias vim nvim


  if status --is-login
    set fish_greeting ""
    fish_vi_key_bindings

    # Use devbox thingy lol ask shane
    if which pstree 1>/dev/null
      if ! pstree -s $fish_pid | grep -q mosh-server
	fix-ssh
      end
    end

    test -f /usr/share/autojump/autojump.fish; and source /usr/share/autojump/autojump.fish

    if which direnv 1>/dev/null
      eval (direnv hook fish)
    end

    # files only, respect gitignore
    set -x FZF_DEFAULT_COMMAND 'fd --type f -I'

    if test -d "$HOME/.cfg"
      # set up config repo
      alias config='git --git-dir=$HOME/.cfg/ --work-tree=$HOME'
      config config --local status.showUntrackedFiles no
    end

    if test -f ~/secrets.fish
      source ~/secrets.fish
    end

    if test -f ~/locals.fish
      source ~/locals.fish
    end

    # use vim as pager
    set -x PAGER "/bin/sh -c \"unset PAGER;col -b -x | \
      vim -R -c 'set ft=man nomod nolist' -c 'map q :q<CR>' \
      -c 'map <SPACE> <C-D>' -c 'map b <C-U>' \
      -c 'nmap K :Man <C-R>=expand(\\\"<cword>\\\")<CR><CR>' -\""

    # always use tmux
    if which tmux 1>/dev/null
      if test "$TERM" != "screen"; and test -z "$TMUX"
	exec tmux new-session -A -s main
      end
    end
  end
end
