function show-text --argument text
  if begin; test $text = '-'; or test $text = '--'; end;
    set text /dev/stdin
  end

  cat $text

  if is-installed pbcopy
    pbcopy <$text
    echo [copied to clipboard]
  end
end
