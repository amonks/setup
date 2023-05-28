#!/bin/sh
ffmpeg -i "$1" -f wav - | lame -V 0 --noreplaygain - "$2"

