function has-setup-option --argument-names name
	if ! set -q $name
		echo "Config unset: $name"
		return 1
	end

	test "$name" = true
end

