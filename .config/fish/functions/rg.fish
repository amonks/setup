function rg
  if test (count $argv) -eq 0
    set got (fzf --bind "start:reload:echo ''" \
        --bind "change:reload:rg --column --line-number --no-heading --color=always --smart-case {q}" \
        --ansi --disabled --layout=reverse)
    set parts (string split : "$got")
    set file $parts[1]
    set line $parts[2]
    set char $parts[3]
    set match $parts[4]
    vim +$line $file
  else
    command rg $argv
  end
end

