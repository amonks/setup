function du
  if begin; status --is-interactive; and which ncdu 1>/dev/null; end
    ncdu --color dark -rr -x --exclude .git --exclude node_modules $argv
  else
    du $argv
  end
end

