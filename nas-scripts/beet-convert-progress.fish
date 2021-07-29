#!/usr/bin/env fish

set total (ls /mypool/data/music | wc -l | string trim)
set dones (ls /mypool/data/mp3 | wc -l | string trim)

echo $dones done
echo $total total

