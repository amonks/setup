function debug-fish-init --argument-names command file
  if test "$debug_fish_init" = "true"
    echo "$command	:: "(date)" :: "(basename $file)
  end
end

