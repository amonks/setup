if status --is-interactive
  if is-installed direnv
    eval (direnv hook fish)
  end
end

