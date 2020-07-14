function ping
  if begin; status --is-interactive; and which prettyping 1>/dev/null; end
    prettyping --nolegend $argv
  else
    command ping $argv
  end
end

