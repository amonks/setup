function wait-for-enter
  if test -n "$argv"
    echo "$argv"
  end
  echo "Press any key to continue"
  read -P 'OK? '
end
