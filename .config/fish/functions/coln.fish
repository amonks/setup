function coln --argument lineno
    while read -l f
        echo $f | awk '{print $'$lineno'}'
    end
end
