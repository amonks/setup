debug-fish-init start (status -f)
  if status --is-interactive
    set -x LESS "-R"
  end
debug-fish-init end (status -f)
