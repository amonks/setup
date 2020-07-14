function alternate --argument-names original replacement
  if begin; status --is-interactive; and is-installed $replacement; end
    $replacement $argv[3..-1]
  else
    command $original $argv[3..-1]
  end
end

