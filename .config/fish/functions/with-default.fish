function with-default --argument-names secondary primary
  if test -n "$primary"
    echo $primary
  else
    echo $secondary
  end
end

