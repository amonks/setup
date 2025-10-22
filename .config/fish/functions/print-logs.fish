function print-logs
    jq -Rr '
      fromjson?
      | if .time and .msg
        then "\u001b[90m" + .time + "\u001b[0m " + .msg
        else .
        end
    '
end

