function download-mp3s-from-thor
  rsync -ha --progress thor:/mypool/tank/music/mp3/ ~/Music/Library-v0
end

