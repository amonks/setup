if status --is-interactive
  if test -f /usr/share/autojump/autojump.fish
    source /usr/share/autojump/autojump.fish
  end
  if test -f /opt/local/share/autojump/autojump.fish
    source /opt/local/share/autojump/autojump.fish
  end
end

