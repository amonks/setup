function forward --argument-names port host
	ssh -nNTL $port:localhost:$port $host
end

