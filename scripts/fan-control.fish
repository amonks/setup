#!/usr/bin/env fish

if test "$machine_name" != "thor"
	echo "must run on thor"
	exit 1
end


# Set fan mode: raw 0x30 0x45 0x01 [x]
# [x] Modes:      CPU Zone  Peripheral Zone
#                 Target    Target
# -------------   --------  ---------------
# 00  Standard    50%      50%
# 01  Full        100%     100%
# 02  Optimal     30%      30%
# 04  Heavy I/O   50%      75%

#set fan mode to "full"
sudo ipmitool raw 0x30 0x45 0x01 0x01

# set fan mode to optimal
sudo ipmitool raw 0x30 0x45 0x01 0x02
