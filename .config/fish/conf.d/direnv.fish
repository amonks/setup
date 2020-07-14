if status --is-interactive
  if which direnv 1>/dev/null 2>&1
    eval (direnv hook fish)
  end
end

