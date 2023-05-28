#!/usr/bin/env fish

yes | pkg install sanoid p5-Config-Inifiles p5-Capture-Tiny pv mbuffer lzop

for cmd in lzop pv mbuffer sanoid syncoid perl
	ln -s /usr/local/bin/$cmd /usr/bin/$cmd
end

