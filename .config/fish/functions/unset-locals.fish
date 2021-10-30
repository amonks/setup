function unset-locals
	for line in (cat ~/locals.fish)
		if string match -rq 'set (?<scope>[A-z-]+) (?<name>[A-z_]+) (?<default>.*)' "$line"
			set --erase $name
		end
	end

	rm ~/locals.fish
end

