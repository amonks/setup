if status --is-interactive
  if which direnv 1>/dev/null
    eval (direnv hook fish)
  end
end

