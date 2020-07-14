function show-text --argument-names text
  echo $text

  if (is-installed pbcopy)
    echo $text | pbcopy
    echo [copied to clipboard]
  end
end
