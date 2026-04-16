function materialize-icloud --argument-names path
    set -l excludes
    for name in (backup-home-exclude-names)
        set -a excludes --exclude $name
    end
    for p in (backup-home-exclude-paths)
        set -a excludes --exclude $p
    end

    fd --type file $excludes --print0 . $path \
        | xargs -0 -P 8 -n 64 head -c 1 > /dev/null
end
