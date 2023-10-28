function download-mp3s-from-thor
  rsync -ha --progress \
    --exclude "/.zfs" \
    thor:/data/tank/music/mp3/ ~/Music/Library-v0
end

