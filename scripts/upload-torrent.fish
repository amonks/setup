#!/usr/bin/env fish

set data_dir /mypool/tank/seeds/data
set torrents_dir /mypool/tank/seeds/torrents

set format $argv[1]
set query $argv[2..-1]

if test -z "$format" || test -z "$query"
	echo "USAGE: upload-torrent \$FORMAT \$QUERY"
	echo " - \$FORMAT can be 'cbr320' or 'v0'"
	echo " - \$QUERY can be one or more words"
	exit 1
end

if test $format != "cbr320" && test $format != "v0"
	echo "invalid format $format; must be 'cbr320' or 'v0'"
	exit 1
end

if ! test -f ~/.config/beets/config-$format.yaml
	echo "config file for format $format not found"
	echo "  ~/.config/beets/config-$format.yaml"
	exit 1
end


set tmp_dir (mktemp -d)
beet -c ~/.config/beets/config-$format.yaml convert --dest $tmp_dir --format $format $query
if test $status -ne 0
	echo "conversion failed"
	exit 1
end
echo Converted to mp3 $format.



set album (ls $tmp_dir)
set album_length (string length "$album")
set longest_track_length (math $album_length + 1)
set longest_track ""
for track in (ls $tmp_dir/$album)
	set track_length (string length "$track")
	set album_and_track_length (math $album_length + 1 + $track_length)
	if test $album_and_track_length -gt $longest_track_length
		set longest_track_length $album_and_track_length
		set longest_track $album/$track
	end
end
if test $longest_track_length -gt 180
	echo "upload would have too-long filenames. go deal with that."
	echo "  $longest_track"
	echo "has length $longest_track_length"
	rm -rf $tmp_dir
	exit 1
end
echo Checked filename length.

mv $tmp_dir/$album $data_dir/$album
rm -rf $tmp_dir
echo Copied into data dir.

sudo chown -R transmission:transmission $data_dir/$album && sudo chmod -R 755 $data_dir/$album
if test $status -ne 0
	echo "error setting data permissions"
	exit 1
end
echo Set data permissions.

set torrentfile "/usr/home/ajm/added/$album.torrent"
transmission-create \
	--private \
	--tracker https://flacsfor.me/c0974f361a92f75d78018f2281c41e44/announce \
	--outfile $torrentfile \
	"$data_dir/$album"
if test $status -ne 0
	echo "error creating torrent file"
	exit 1
end
echo Created torrent file.

