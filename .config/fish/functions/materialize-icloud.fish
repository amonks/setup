function materialize-icloud --argument-names path
  fd --type file --print0 . $path | xargs -0 head -c 1 > /dev/null
end

