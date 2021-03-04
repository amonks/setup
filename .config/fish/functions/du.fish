function du
  if begin; status --is-interactive; and is-installed ncdu; end
    ncdu --color dark -rr -x --exclude .git --exclude node_modules $argv
  else
    command du $argv
  end
end

