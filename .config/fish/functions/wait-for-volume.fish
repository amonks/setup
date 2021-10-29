function wait-for-volume --argument-names volume
  while ! test -d $volume
    sleep 0.5
  end
end

