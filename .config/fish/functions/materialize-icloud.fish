function materialize-icloud --argument-names path
  fd \
    --type file \
    --exclude "Library" \
    --exclude ".cache" \
    --exclude ".zfs" \
    --exclude "AppleInternal" \
    --exclude "Library" \
    --exclude "Library/Fonts" \
    --exclude "Music/Library-v0" \
    --exclude "mnt" \
    --print0 \
    . $path \
    | xargs -0 head -c 1 > /dev/null
end

