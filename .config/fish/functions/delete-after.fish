function delete-after --argument-names filename pattern
  if test -z "$pattern"
    echo "usage: delete-after \$filename \$pattern"
    echo "(deletes the line after line containing \$pattern)"
    return 1
  end

  # by copying the file before replacing it, we retain its chmod stuff
  cp "$filename" "$filename".tmp

  sed -e '/'$pattern'/{n;d;}' "$filename" > "$filename.tmp"
  mv "$filename".tmp "$filename"
end

