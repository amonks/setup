function is-installed --argument-names bin
  which $bin 1>/dev/null 2>&1
end

