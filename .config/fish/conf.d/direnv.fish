if status --is-interactive
  if is-installed direnv
    direnv hook fish | source
  end
end

