function wait-for --description "wait-for <duration> <...description>"
	for i in (seq $argv[1] 1)
		echo waiting $i seconds for $argv[2..-1]
		sleep 1
	end
end


