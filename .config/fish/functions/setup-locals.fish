function setup-locals
  if test -f ~/locals.fish
    source ~/locals.fish
  else
    touch ~/locals.fish
  end

  for line in (cat ~/locals.fish.example)
    if string match -rq 'set (?<scope>[A-z-]+) (?<name>[A-z_]+) (?<default>.*)' "$line"
      if test -z "$name"
        echo "Failed to parse line: $line"
        return 1
      end

      if set -q $name
        continue
      end

      set default_value (eval echo $default)
      read --prompt='set_color green; echo -n "$name? [$default_value] "; set_color normal;' response
      if test -z "$response"
        echo "set $scope $name $default_value" >> ~/locals.fish
      else
        echo "set $scope $name $response" >> ~/locals.fish
      end
    end
  end

  source ~/locals.fish
end

