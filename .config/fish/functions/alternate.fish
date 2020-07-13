function alternate --argument-names original replacement
  if begin; status --is-interactive; and which $replacement 1>/dev/null 2>&1; end
    $replacement $argv[3..-1]
  else
    command $original $argv[3..-1]
  end
end

