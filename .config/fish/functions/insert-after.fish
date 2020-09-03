function insert-after --argument-names filename pattern insertion
  if test -z "$insertion"
    echo "usage: insert-after \$filename \$pattern \$insertion"
    echo "(inserts \$insertion into \$filename after line containing \$pattern)"
    return 1
  end

  # by copying the file before replacing it, we retain its chmod stuff
  cp "$filename" "$filename".tmp

  awk -v text="$insertion" '/'"$pattern"'/ {print $0 RS text;next} 1' "$filename" > "$filename".tmp
  mv "$filename".tmp "$filename"
end

