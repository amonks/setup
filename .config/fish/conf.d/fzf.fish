debug-fish-init start (status -f)
  if status --is-interactive
    # files only, respect gitignore
    set -x FZF_DEFAULT_COMMAND 'fd --type f -I'
  end
debug-fish-init end (status -f)

