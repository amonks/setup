debug-fish-init start (status -f)
  if status --is-interactive
    fish_vi_key_bindings
  end
debug-fish-init stop (status -f)

