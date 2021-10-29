function killsearch --argument-names query signal_name
	set -q signal_name[1]; or set signal_name TERM
	ps -eo command | grep "$query" | grep -v grep | cut -f1 -d' ' | xargs -n 1 -I % sh -c "ps -o pid,command -p % | tail -n1 && kill -s $signal_name %"
end

