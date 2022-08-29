debug-fish-init start (status -f)
  if test -f ~/secrets.fish
    source ~/secrets.fish
  end

  if test -f ~/locals.fish
    source ~/locals.fish
  end
debug-fish-init end (status -f)

