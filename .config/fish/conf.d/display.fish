debug-fish-init start (status -f)
  if status --is-interactive
    set -x fish_emoji_width 1
    set -x fish_ambiguous_width 1
  end
debug-fish-init end (status -f)

