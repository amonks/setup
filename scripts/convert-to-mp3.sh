#!/bin/sh

format="$1"
src="$2"
dest="$3"

# echo "format: $format"
# echo "src: $src"
# echo "dest: $dest"

if test "$format" = "v0" ; then
  ffmpeg -i "$src" -f wav - | lame -V 0 --noreplaygain - "$dest"
elif test "$format" = "320" ; then
  ffmpeg -i "$src" -f wav - | lame --cbr -b 320 --noreplaygain - "$dest"
else
  echo "unexpected format: '$format'"
  exit 1
fi

