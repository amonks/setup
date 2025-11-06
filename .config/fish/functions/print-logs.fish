function print-logs
    jq -Rr '
      (fromjson? // .)
      | if type == "object" and .time and .msg
        then
          (del(.time, .msg, .pid, .hostname, .name)) as $rest
          | "\u001b[90m" + .time + "\u001b[0m " + .msg +
            (if .level != "info" and ($rest | length) > 0
             then "\n" + ($rest | to_entries | map("  \u001b[90m" + .key + ":\u001b[0m \u001b[36m" + (.value | tojson) + "\u001b[0m") | join("\n"))
             else ""
             end)
        else .
        end
    '
end

