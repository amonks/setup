#!/usr/bin/env fish

set total (cat beet-import.log | grep '^import' | wc -l | string trim)
set skips (cat beet-import.log | grep '^skip' | wc -l | string trim)
set dupes (cat beet-import.log | grep '^duplicate' | wc -l | string trim)
set dones (math $total - $skips - $dupes)

echo $dones done
echo $skips skipped
echo $dupes dupes
echo $total total

