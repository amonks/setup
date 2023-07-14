function cat
  if begin; status --is-interactive; and is-installed bat; end
    bat --no-pager $argv
  else
    cat $argv
  end
end

