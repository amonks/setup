function ping
  if begin; status --is-interactive; and is-installed prettyping; end
    prettyping --nolegend $argv
  else
    command ping $argv
  end
end

