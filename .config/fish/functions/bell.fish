function bell --argument-names count
  echo -n \a

  if test -n "$count"
    if test $count -gt 1
      for i in (seq 2 $count)
        sleep 0.1
        echo -n \a
      end
    end
  end
end

