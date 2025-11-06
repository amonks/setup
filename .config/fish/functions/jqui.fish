function jqui --argument-names file
  fzf --bind "start:reload:jq --color-output -r . $file" \
      --bind "change:reload:jq --color-output -r {q} $file || true" \
      --ansi --disabled --layout=reverse
end

